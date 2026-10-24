///|
/// The keys that import writes, in order, from the derived metadata.
let import_keys : Array[String] = [
  "type", "title", "description", "capability", "change", "state", "heading",
]

///|
fn description_of(doc : @okf.Document) -> String? {
  // The first paragraph line of `## Purpose` or `## Why`, else none.
  let lines = doc.prose_lines()
  let mut in_section = false
  for pair in lines {
    match heading(pair.1) {
      Some((2, text)) => in_section = text == "Purpose" || text == "Why"
      Some(_) => if in_section { break }
      None =>
        if in_section {
          let t = pair.1.trim(chars=" \t").to_owned()
          if t.length() > 0 && !t.has_prefix("<!--") {
            return Some(t)
          }
        }
    }
  }
  None
}

///|
fn store_path(root : ArrayView[String], rel : String) -> @okf.StorePath raise {
  if root.is_empty() {
    @okf.StorePath(rel)
  } else {
    @okf.StorePath(root.iter().collect().join("/") + "/" + rel)
  }
}

///|
/// Plans the import of the `openspec/` tree at `source_root` of `set` into a
/// native OKF bundle at `target_root`: one concept for each specification,
/// change, design, task list and spec delta, with frontmatter and the
/// original body, plus a root `index.md` and a `log.md` dated `date`. Other
/// files, such as `.openspec.yaml`, are copied as assets.
pub fn import_openspec(
  set : @okf.DocumentSet,
  source_root : ArrayView[String],
  target_root : ArrayView[String],
  date : String,
) -> @edit.EditPlan raise {
  guard date.length() == 10 &&
    @okf.Instant::parse(date, date_only=true) is Some(_) else {
    raise InvalidDate(date)
  }
  let profile : &@okf.Profile = OpenSpecProfile::{ }
  let bundle = @okf.load_bundle(set, root=source_root, profiles=[profile])
  let changes = []
  let entries : Array[(String, String, String, String?)] = []
  for doc in bundle.documents() {
    guard doc.is_derived() else { continue }
    let meta = doc.metadata()
    let lines = ["---"]
    for key in import_keys {
      let value = if key == "description" {
        description_of(doc)
      } else {
        meta.text(key)
      }
      match value {
        Some(v) => lines.push("\{key}: \{@edit.yaml_scalar(v)}")
        None => ()
      }
    }
    lines.push("---")
    let text = lines.join("\n") + "\n" + doc.text()
    changes.push(
      @edit.FileChange::Create(
        path=store_path(target_root, doc.path().to_string()[1:].to_owned()),
        text~,
      ),
    )
    entries.push(
      (
        meta.concept_type().unwrap_or(""),
        doc.display_title(),
        doc.path().to_string(),
        description_of(doc),
      ),
    )
  }
  for asset in bundle.assets() {
    match set.get(bundle.store_path_of(asset)) {
      Some(entry) => {
        let path = store_path(target_root, asset.to_string()[1:].to_owned())
        changes.push(
          match entry.content {
            Bytes(bytes) => @edit.FileChange::CreateBinary(path~, bytes~)
            Text(text) => @edit.FileChange::Create(path~, text~)
          },
        )
      }
      None => ()
    }
  }
  changes.push(
    @edit.FileChange::Create(
      path=store_path(target_root, "index.md"),
      text=index_text(entries),
    ),
  )
  changes.push(
    @edit.FileChange::Create(
      path=store_path(target_root, "log.md"),
      text="# Log\n\n## \{date}\n\n* **Creation**: Imported from OpenSpec.\n",
    ),
  )
  @edit.EditPlan(changes)
}

///|
fn index_text(
  entries : Array[(String, String, String, String?)],
) -> String raise @edit.EditError {
  let types = []
  for e in entries {
    if !types.contains(e.0) {
      types.push(e.0)
    }
  }
  types.sort_by(@okf.lexical_compare)
  let out = ["---", "okf_version: \"0.2\"", "---", ""]
  for t in types {
    out.push("# \{t}")
    out.push("")
    let items = entries.iter().filter(e => e.0 == t).collect()
    items.sort_by((a, b) => @okf.lexical_compare(a.2, b.2))
    for e in items {
      out.push(@edit.index_entry_line(e.1, e.2, description?=e.3))
    }
    out.push("")
  }
  out.join("\n")
}

///|
/// The path of an OpenSpec file for a native concept, from its metadata.
fn export_path(meta : @okf.Metadata) -> String? raise ConvertError {
  let t = meta.concept_type().unwrap_or("")
  let capability = () => {
    match meta.text("capability") {
      Some(c) => Some(check_name("capability", c, segments=true))
      None => None
    }
  }
  let change_dir = () => {
    match meta.text("change") {
      Some(c) => {
        let c = check_name("change", c, segments=false)
        Some(
          if meta.text("state") == Some("archived") {
            "changes/archive/\{c}"
          } else {
            "changes/\{c}"
          },
        )
      }
      None => None
    }
  }
  if t == specification_type {
    capability().map(c => "specs/\{c}/spec.md")
  } else if t == change_type {
    change_dir().map(d => d + "/proposal.md")
  } else if t == design_type {
    change_dir().map(d => d + "/design.md")
  } else if t == tasks_type {
    change_dir().map(d => d + "/tasks.md")
  } else if t == delta_type {
    match (change_dir(), capability()) {
      (Some(d), Some(c)) => Some("\{d}/specs/\{c}/spec.md")
      _ => None
    }
  } else {
    None
  }
}

///|
/// Raised when a conversion cannot use a value of a concept.
pub(all) suberror ConvertError {
  /// A `capability` or `change` value that is not a safe OpenSpec name: an
  /// empty segment, `.`, `..`, a segment that starts or ends with `.` or ends
  /// with a space, a Windows device name such as `CON`, a control character, or
  /// one of `\ : * ? " < > |` (and `/` outside the separators between
  /// capability segments).
  InvalidName(key~ : String, value~ : String)
  /// A log date that is not a real calendar date in the form `YYYY-MM-DD`.
  InvalidDate(String)
} derive(Eq, Debug)

///|
/// Checks that `value` is a safe OpenSpec name, so that a path built from it
/// stays inside the target directory. `segments=true` allows `/` between
/// segments, as capability paths have.
fn check_name(
  key : String,
  value : String,
  segments~ : Bool,
) -> String raise ConvertError {
  let parts = if segments {
    value.split("/").map(p => p.to_owned()).collect()
  } else {
    [value]
  }
  for part in parts {
    let ok = part.length() > 0 &&
      part != "." &&
      part != ".." &&
      !part.has_prefix(".") &&
      !part.has_suffix(".") &&
      !part.has_suffix(" ") &&
      !is_windows_device(part) &&
      part.iter().all(c => c.to_int() >= 32 && !"\\/:*?\"<>|".contains_char(c))
    if !ok {
      raise InvalidName(key~, value~)
    }
  }
  value
}

///|
/// True when `value` is a safe capability path.
fn is_safe_capability(value : String) -> Bool {
  try check_name("capability", value, segments=true) catch {
    _ => false
  } noraise {
    _ => true
  }
}

///|
/// Plans the export of the native OKF bundle at `source_root` of `set` into an
/// `openspec/` tree at `target_root`. Each OpenSpec concept becomes its file
/// without frontmatter; Requirement and Scenario concepts merge into their
/// capability spec, in order. Assets are copied; `index.md` and `log.md` are not.
pub fn export_openspec(
  set : @okf.DocumentSet,
  source_root : ArrayView[String],
  target_root : ArrayView[String],
) -> @edit.EditPlan raise {
  let bundle = @okf.load_bundle(set, root=source_root)
  let changes = []
  let requirements = of_type(bundle, requirement_type)
  let scenarios = of_type(bundle, scenario_type)
  for doc in bundle.concepts() {
    let meta = doc.metadata()
    guard export_path(meta) is Some(rel) else { continue }
    let mut text = doc.body()
    if meta.concept_type() == Some(specification_type) {
      let cap = meta.text("capability").unwrap_or("")
      let extra = []
      for r in requirements {
        guard r.metadata().text("capability") == Some(cap) else { continue }
        let name = r.metadata().text("requirement").unwrap_or(r.display_title())
        extra.push(
          "### Requirement: \{name}\n" +
          r.body().trim_end(chars="\n").to_owned() +
          "\n",
        )
        for s in scenarios {
          if s.metadata().text("capability") == Some(cap) &&
            s.metadata().text("requirement") == Some(name) {
            let sname = s
              .metadata()
              .text("scenario")
              .unwrap_or(s.display_title())
            extra.push(
              "#### Scenario: \{sname}\n" +
              s.body().trim_end(chars="\n").to_owned() +
              "\n",
            )
          }
        }
      }
      if !extra.is_empty() {
        let base = text.trim_end(chars="\n").to_owned()
        let needs_heading = !base.contains("## Requirements")
        text = base +
          "\n\n" +
          (if needs_heading { "## Requirements\n\n" } else { "" }) +
          extra.join("\n")
      }
    }
    changes.push(
      @edit.FileChange::Create(path=store_path(target_root, rel), text~),
    )
  }
  for asset in bundle.assets() {
    match set.get(bundle.store_path_of(asset)) {
      Some(entry) => {
        let path = store_path(target_root, asset.to_string()[1:].to_owned())
        changes.push(
          match entry.content {
            Bytes(bytes) => @edit.FileChange::CreateBinary(path~, bytes~)
            Text(text) => @edit.FileChange::Create(path~, text~)
          },
        )
      }
      None => ()
    }
  }
  @edit.EditPlan(changes)
}

///|
pub extend ConvertError with Eq::{not_equal, equal}

///|
pub extend ConvertError with @debug.Debug::{to_repr}

///|
/// True for a Windows device name, such as `CON` or `com1.txt`, which a Windows
/// file system cannot use as a file name.
fn is_windows_device(part : String) -> Bool {
  let stem = match part.find(".") {
    Some(i) => part[:i].to_owned()
    None => part
  }
  let upper = stem.to_upper()
  ["CON", "PRN", "AUX", "NUL"].contains(upper) ||
  (
    upper.length() == 4 &&
    (upper.has_prefix("COM") || upper.has_prefix("LPT")) &&
    upper[3] >= '1' &&
    upper[3] <= '9'
  )
}
