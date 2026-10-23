///|
/// One change of an edit plan.
pub(all) enum FileChange {
  Create(path~ : @okf.StorePath, text~ : String)
  Update(path~ : @okf.StorePath, before~ : String, after~ : String)
  Delete(path~ : @okf.StorePath)
} derive(Eq, Debug)

///|
pub fn FileChange::path(self : FileChange) -> @okf.StorePath {
  match self {
    Create(path~, ..) | Update(path~, ..) | Delete(path~) => path
  }
}

///|
/// An ordered set of file changes. Nothing is written until a caller applies
/// the plan to a document set or a store.
struct EditPlan {
  changes : ReadOnlyArray[FileChange]
}

///|
/// A plan from changes. An update whose text does not change is left out, and
/// a later change to the same path replaces an earlier one.
pub fn EditPlan::EditPlan(changes : ArrayView[FileChange]) -> EditPlan {
  let out : Array[FileChange] = []
  for change in changes {
    if change is Update(before~, after~, ..) && before == after {
      continue
    }
    match out.search_by(c => c.path() == change.path()) {
      Some(i) =>
        out[i] = match (out[i], change) {
          (Create(..), Update(path~, after~, ..)) => Create(path~, text=after)
          (Update(path~, before~, ..), Update(after~, ..)) =>
            Update(path~, before~, after~)
          _ => change
        }
      None => out.push(change)
    }
  }
  { changes: ReadOnlyArray::from_array(out), }
}

///|
pub fn EditPlan::changes(self : EditPlan) -> ReadOnlyArray[FileChange] {
  self.changes
}

///|
pub fn EditPlan::is_empty(self : EditPlan) -> Bool {
  self.changes.is_empty()
}

///|
/// A plan with the changes of `self` followed by those of `other`.
pub fn EditPlan::then(self : EditPlan, other : EditPlan) -> EditPlan {
  let all = self.changes.iter().collect()
  for c in other.changes {
    all.push(c)
  }
  EditPlan(all)
}

///|
/// A dry-run description: one line per change, then each new or changed text
/// with `+` and `-` lines for the lines that differ.
pub fn EditPlan::render(self : EditPlan) -> String {
  let out = StringBuilder()
  for change in self.changes {
    match change {
      Create(path~, text~) => {
        out.write_string("create \{path}\n")
        for l in @okf.split_lines(text) {
          out.write_string("+ \{l.text}\n")
        }
      }
      Update(path~, before~, after~) => {
        out.write_string("update \{path}\n")
        let a = @okf.split_lines(before).map(l => l.text)
        let b = @okf.split_lines(after).map(l => l.text)
        for l in a {
          if !b.contains(l) {
            out.write_string("- \{l}\n")
          }
        }
        for l in b {
          if !a.contains(l) {
            out.write_string("+ \{l}\n")
          }
        }
      }
      Delete(path~) => out.write_string("delete \{path}\n")
    }
  }
  out.to_string()
}

///|
/// Applies the plan to an in-memory document set and returns the new set.
pub fn EditPlan::apply_to(
  self : EditPlan,
  set : @okf.DocumentSet,
) -> @okf.DocumentSet {
  let mut current = set
  for change in self.changes {
    current = match change {
      Create(path~, text~) | Update(path~, after=text, ..) =>
        current.with_entry({ path, content: Text(text), })
      Delete(path~) => current.without(path)
    }
  }
  current
}

///|
/// Why a new concept path is refused.
pub(all) suberror PathRefused {
  /// The file name is `index.md` or `log.md`.
  ReservedName(String)
  /// The path leaves the bundle.
  EscapesBundle(String)
  /// A document already exists at the path.
  AlreadyExists(String)
  /// The path does not end with `.md`.
  NotMarkdown(String)
} derive(Eq, Debug)

///|
/// Validates the path of a new concept in `bundle`.
pub fn check_new_concept_path(
  bundle : @okf.Bundle,
  path : String,
) -> @okf.BundlePath raise PathRefused {
  let p = @okf.BundlePath(path) catch { _ => raise EscapesBundle(path) }
  let name = p.name().to_lower()
  if name == "index.md" || name == "log.md" {
    raise ReservedName(p.name())
  }
  if !@okf.is_markdown_name(name) {
    raise NotMarkdown(path)
  }
  if bundle.document(p) is Some(_) {
    raise AlreadyExists(p.to_string())
  }
  p
}

///|
/// The index that should list a concept at `path`: the `index.md` of the
/// nearest directory at or above the concept, else the root index.
pub fn target_index(
  bundle : @okf.Bundle,
  path : @okf.BundlePath,
) -> @okf.BundlePath? {
  let dir = path.directory()
  while true {
    let candidate = dir.copy()
    candidate.push("index.md")
    let p = @okf.BundlePath(candidate.join("/")) catch { _ => break }
    if bundle.document(p) is Some(_) {
      return Some(p)
    }
    if dir.is_empty() {
      break
    }
    dir.pop() |> ignore
  }
  None
}

///|
/// The destination of an index entry in `index` for a concept at `concept`:
/// a bundle-rooted path.
fn entry_destination(concept : @okf.BundlePath) -> String {
  concept.to_string()
}

///|
/// The text of a new concept: frontmatter with `type`, `title`, `description`
/// and the extra fields in order, then the template body. The template can use
/// `{{title}}`, `{{description}}` and `{{type}}`.
pub fn new_concept_text(
  concept_type : String,
  title : String,
  description : String,
  fields~ : ArrayView[(String, String)] = [],
  template? : @okf.Template,
) -> String {
  let lines = [
    "---",
    "type: \{yaml_scalar(concept_type)}",
    "title: \{yaml_scalar(title)}",
    "description: \{yaml_scalar(description)}",
  ]
  for f in fields {
    lines.push("\{f.0}: \{f.1}")
  }
  lines.push("---")
  let body = match template {
    Some(t) =>
      t.body
      .replace_all(old="{{title}}", new=title)
      .replace_all(old="{{description}}", new=description)
      .replace_all(old="{{type}}", new=concept_type)
    None => "# \{title}\n\n\{description}\n"
  }
  lines.join("\n") + "\n\n" + body
}

///|
/// Plans a new concept: its file, an entry in its target index (in the
/// section `section`), and a `Creation` entry in the root log for `date`.
/// `fields` are raw YAML values.
pub fn plan_add_concept(
  bundle : @okf.Bundle,
  path : String,
  concept_type : String,
  title : String,
  description : String,
  date : String,
  fields~ : ArrayView[(String, String)] = [],
  section~ : String = concept_type,
  template? : @okf.Template,
) -> EditPlan raise {
  let p = check_new_concept_path(bundle, path)
  let text = new_concept_text(
    concept_type,
    title,
    description,
    fields~,
    template?,
  )
  let changes = [Create(path=bundle.store_path_of(p), text~)]
  match target_index(bundle, p) {
    Some(index_path) =>
      match bundle.document(index_path) {
        Some(index) => {
          let entry = index_entry_line(
            title,
            entry_destination(p),
            description~,
          )
          let r = add_index_entry(index.text(), section, entry)
          changes.push(
            Update(path=index.store_path(), before=index.text(), after=r.text),
          )
        }
        None => ()
      }
    None => ()
  }
  match bundle.root_log() {
    Some(log) => {
      let r = add_log_entry(
        log.text(),
        date,
        "Added [\{title}](\{p}).",
        label="Creation",
      )
      changes.push(
        Update(path=log.store_path(), before=log.text(), after=r.text),
      )
    }
    None => ()
  }
  EditPlan(changes)
}

///|
/// Plans the description refresh of every drifted index entry of `bundle`.
pub fn plan_refresh_descriptions(bundle : @okf.Bundle) -> EditPlan raise {
  let texts : Map[@okf.StorePath, String] = Map([])
  let originals : Map[@okf.StorePath, String] = Map([])
  for drift in bundle.description_drift() {
    let path = drift.index.store_path()
    let before = texts.get(path).unwrap_or(drift.index.text())
    originals[path] = originals.get(path).unwrap_or(drift.index.text())
    let r = refresh_index_entry(before, drift.entry.destination, drift.expected)
    texts[path] = r.text
  }
  EditPlan(
    texts
    .iter()
    .map(pair => {
      Update(
        path=pair.0,
        before=originals.get(pair.0).unwrap_or(""),
        after=pair.1,
      )
    })
    .collect(),
  )
}

///|
/// Plans the addition of an entry for each concept that no index lists, in
/// the section `section` of its target index.
pub fn plan_add_missing_entries(
  bundle : @okf.Bundle,
  section : String,
) -> EditPlan raise {
  let texts : Map[@okf.StorePath, String] = Map([])
  let originals : Map[@okf.StorePath, String] = Map([])
  for concept in bundle.unindexed_concepts() {
    match target_index(bundle, concept.path()) {
      Some(index_path) =>
        match bundle.document(index_path) {
          Some(index) => {
            let path = index.store_path()
            let before = texts.get(path).unwrap_or(index.text())
            originals[path] = originals.get(path).unwrap_or(index.text())
            let entry = index_entry_line(
              concept.display_title(),
              entry_destination(concept.path()),
              description?=concept.metadata().description(),
            )
            texts[path] = add_index_entry(before, section, entry).text
          }
          None => ()
        }
      None => ()
    }
  }
  EditPlan(
    texts
    .iter()
    .map(pair => {
      Update(
        path=pair.0,
        before=originals.get(pair.0).unwrap_or(""),
        after=pair.1,
      )
    })
    .collect(),
  )
}

///|
/// Raised when a register refuses a transition.
pub(all) suberror TransitionRefused {
  TransitionRefused(@okf.TransitionCheck)
} derive(Debug)

///|
/// Plans a register transition: it sets the state key to `to`, and sets the
/// extra keys (raw YAML values) in the same edit. The check runs on the record
/// as it would be after the extra keys apply, and the transition is refused
/// before any edit when an obligation is unmet.
pub fn plan_transition(
  register : @okf.Register,
  record : @okf.Record,
  to : String,
  extra~ : ArrayView[(String, String)] = [],
) -> EditPlan raise {
  guard register.state_key is Some(state_key) else {
    fail("the register \{register.name} has no state key")
  }
  let doc = record.document
  let updates : Array[(String, String?)] = [(state_key, Some(yaml_scalar(to)))]
  for e in extra {
    updates.push((e.0, Some(e.1)))
  }
  let after = set_raw_keys(doc.text(), updates).text
  let preview = @okf.Document(doc.path(), doc.store_path(), after)
  let check = register.check_transition({ ..record, document: preview, }, to)
  match check {
    Allowed => ()
    other => raise TransitionRefused(other)
  }
  EditPlan([Update(path=doc.store_path(), before=doc.text(), after~)])
}

///|
pub extend FileChange with Eq::{not_equal, equal}

///|
pub extend FileChange with @debug.Debug::{to_repr}

///|
pub extend PathRefused with Eq::{not_equal, equal}

///|
pub extend PathRefused with @debug.Debug::{to_repr}

///|
pub extend TransitionRefused with @debug.Debug::{to_repr}
