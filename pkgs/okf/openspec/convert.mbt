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
      Some(entry) =>
        changes.push(
          @edit.FileChange::Create(
            path=store_path(target_root, asset.to_string()[1:].to_owned()),
            text=entry.content.text(),
          ),
        )
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
fn index_text(entries : Array[(String, String, String, String?)]) -> String {
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
fn export_path(meta : @okf.Metadata) -> String? {
  let t = meta.concept_type().unwrap_or("")
  let change_dir = () => {
    match meta.text("change") {
      Some(c) =>
        Some(
          if meta.text("state") == Some("archived") {
            "changes/archive/\{c}"
          } else {
            "changes/\{c}"
          },
        )
      None => None
    }
  }
  if t == specification_type {
    meta.text("capability").map(c => "specs/\{c}/spec.md")
  } else if t == change_type {
    change_dir().map(d => d + "/proposal.md")
  } else if t == design_type {
    change_dir().map(d => d + "/design.md")
  } else if t == tasks_type {
    change_dir().map(d => d + "/tasks.md")
  } else if t == delta_type {
    match (change_dir(), meta.text("capability")) {
      (Some(d), Some(c)) => Some("\{d}/specs/\{c}/spec.md")
      _ => None
    }
  } else {
    None
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
      Some(entry) =>
        changes.push(
          @edit.FileChange::Create(
            path=store_path(target_root, asset.to_string()[1:].to_owned()),
            text=entry.content.text(),
          ),
        )
      None => ()
    }
  }
  @edit.EditPlan(changes)
}
