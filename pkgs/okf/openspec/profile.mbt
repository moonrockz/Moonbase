///|
/// The OKF types that the OpenSpec profile defines.
pub let specification_type : String = "Specification"

///|
pub let change_type : String = "Change"

///|
pub let design_type : String = "Design"

///|
pub let tasks_type : String = "Tasks"

///|
pub let delta_type : String = "Spec Delta"

///|
pub let requirement_type : String = "Requirement"

///|
pub let scenario_type : String = "Scenario"

///|
/// What an OpenSpec path holds.
pub(all) enum Kind {
  SpecFile(capability~ : String)
  ProposalFile(change~ : String, archived~ : Bool)
  DesignFile(change~ : String, archived~ : Bool)
  TasksFile(change~ : String, archived~ : Bool)
  DeltaFile(change~ : String, archived~ : Bool, capability~ : String)
} derive(Eq, Debug)

///|
/// Classifies a path inside an `openspec/` tree.
pub fn classify(path : @okf.BundlePath) -> Kind? {
  let s = path.segments().iter().collect()
  let n = s.length()
  if n >= 3 && s[0] == "specs" && s[n - 1] == "spec.md" {
    return Some(SpecFile(capability=s[1:n - 1].to_owned().join("/")))
  }
  guard n >= 3 && s[0] == "changes" else { return None }
  let (archived, rest) = if s[1] == "archive" && n >= 4 {
    (true, s[2:].to_owned())
  } else {
    (false, s[1:].to_owned())
  }
  let change = rest[0]
  let m = rest.length()
  match rest[1:].to_owned() {
    ["proposal.md"] => Some(ProposalFile(change~, archived~))
    ["design.md"] => Some(DesignFile(change~, archived~))
    ["tasks.md"] => Some(TasksFile(change~, archived~))
    ["specs", .., "spec.md"] if m >= 4 =>
      Some(
        DeltaFile(
          change~,
          archived~,
          capability=rest[2:m - 1].to_owned().join("/"),
        ),
      )
    _ => None
  }
}

///|
fn first_heading(doc : @okf.Document) -> String? {
  for pair in doc.prose_lines() {
    match heading(pair.1) {
      Some((_, text)) => return Some(text)
      None => ()
    }
  }
  None
}

///|
fn state_of(archived : Bool) -> String {
  if archived {
    "archived"
  } else {
    "active"
  }
}

///|
/// The metadata that the profile derives for a file of an `openspec/` tree.
pub fn derived_fields(doc : @okf.Document) -> @okf.Fields? {
  let pairs : Array[(String, @okf.Value)] = []
  let text = (k : String, v : String) => pairs.push((k, Scalar(v)))
  match classify(doc.path()) {
    None => return None
    Some(SpecFile(capability~)) => {
      text("type", specification_type)
      text("title", capability)
      text("capability", capability)
    }
    Some(ProposalFile(change~, archived~)) => {
      text("type", change_type)
      text("title", change)
      text("change", change)
      text("state", state_of(archived))
    }
    Some(DesignFile(change~, archived~)) => {
      text("type", design_type)
      text("title", change + " design")
      text("change", change)
      text("state", state_of(archived))
    }
    Some(TasksFile(change~, archived~)) => {
      text("type", tasks_type)
      text("title", change + " tasks")
      text("change", change)
      text("state", state_of(archived))
    }
    Some(DeltaFile(change~, archived~, capability~)) => {
      text("type", delta_type)
      text("title", change + ": " + capability)
      text("change", change)
      text("capability", capability)
      text("state", state_of(archived))
    }
  }
  match first_heading(doc) {
    Some(h) => pairs.push(("heading", Scalar(h)))
    None => ()
  }
  Some(@okf.Fields(pairs))
}

///|
/// The OpenSpec profile. It reads `openspec/` trees as OKF bundles, defines
/// native OKF types for OpenSpec content, links changes to capabilities, and
/// adds the OpenSpec checks.
pub(all) struct OpenSpecProfile {}

///|
pub impl @okf.Profile for OpenSpecProfile with fn name(_) {
  "openspec"
}

///|
pub impl @okf.Profile for OpenSpecProfile with fn vocabulary(_) {
  [
    @okf.KeyDefinition(
      "capability",
      description="The capability path, such as `okf/documents`.",
    ),
    @okf.KeyDefinition("change", description="The change name."),
    @okf.KeyDefinition(
      "state",
      values=["active", "archived"],
      description="The state of a change.",
    ),
    @okf.KeyDefinition(
      "requirement",
      description="The requirement name of a Requirement or Scenario concept.",
    ),
    @okf.KeyDefinition(
      "scenario",
      description="The scenario name of a Scenario concept.",
    ),
    @okf.KeyDefinition(
      "order",
      description="The position of a Requirement or Scenario concept.",
    ),
    @okf.KeyDefinition(
      "heading",
      description="The first heading of the original file.",
    ),
  ]
}

///|
pub impl @okf.Profile for OpenSpecProfile with fn derive_metadata(_, doc) {
  derived_fields(doc)
}

///|
pub impl @okf.Profile for OpenSpecProfile with fn rule_sets(_) {
  [openspec_checks()]
}

///|
fn link_to(target : String) -> @okf.Link {
  @okf.Link("", target)
}

///|
fn spec_path(capability : String) -> String {
  "/specs/\{capability}/spec.md"
}

///|
pub impl @okf.Profile for OpenSpecProfile with fn relations(_, bundle, doc) {
  let meta = doc.metadata()
  let t = meta.concept_type().unwrap_or("")
  let out = []
  if t == change_type {
    let dir = doc.path().directory()
    let prefix = "/" + dir.join("/")
    for other in bundle.documents() {
      let segs = other.path().segments()
      guard other.path() != doc.path() && segs.length() > dir.length() else {
        continue
      }
      let mut inside = true
      for i, s in dir {
        if segs[i] != s {
          inside = false
          break
        }
      }
      guard inside else { continue }
      match other.metadata().concept_type() {
        Some(ot) if ot == design_type || ot == tasks_type || ot == delta_type =>
          out.push(link_to(other.path().to_string()))
        _ => ()
      }
      if other.metadata().concept_type() == Some(delta_type) {
        match other.metadata().text("capability") {
          Some(cap) => out.push(link_to(spec_path(cap)))
          None => ()
        }
      }
    }
    ignore(prefix)
  } else if t == delta_type || t == requirement_type || t == scenario_type {
    match meta.text("capability") {
      Some(cap) => out.push(link_to(spec_path(cap)))
      None => ()
    }
  }
  out
}

///|
/// The concepts of a type, sorted by `order` and then by path.
fn of_type(bundle : @okf.Bundle, t : String) -> Array[@okf.Document] {
  let docs = bundle
    .concepts()
    .iter()
    .filter(d => d.metadata().concept_type() == Some(t))
    .collect()
  docs.sort_by((a, b) => {
    let oa = a.metadata().int("order").unwrap_or(0)
    let ob = b.metadata().int("order").unwrap_or(0)
    if oa != ob {
      oa.compare(ob)
    } else {
      a.path().compare(b.path())
    }
  })
  docs
}

///|
/// The structured OpenSpec view of a bundle, from an `openspec/` tree (with
/// this profile's derived metadata) or from a native bundle.
pub fn view(bundle : @okf.Bundle) -> OpenSpecView {
  let requirement_docs = of_type(bundle, requirement_type)
  let scenario_docs = of_type(bundle, scenario_type)
  let specs = of_type(bundle, specification_type).map(doc => {
    let cap = doc.metadata().text("capability").unwrap_or(doc.display_title())
    let model = parse_spec(cap, doc.prose_lines())
    for r in requirement_docs {
      if r.metadata().text("capability") == Some(cap) {
        let name = r.metadata().text("requirement").unwrap_or(r.display_title())
        let parsed = parse_spec(
          cap,
          [(0, "### Requirement: " + name)] + r.prose_lines(),
        )
        for req in parsed.requirements {
          model.requirements.push(req)
        }
      }
    }
    for s in scenario_docs {
      if s.metadata().text("capability") == Some(cap) {
        let req_name = s.metadata().text("requirement").unwrap_or("")
        let name = s.metadata().text("scenario").unwrap_or(s.display_title())
        let parsed = parse_spec(
          cap,
          [(0, "### Requirement: x"), (0, "#### Scenario: " + name)] +
          s.prose_lines(),
        )
        match model.requirements.search_by(r => r.name == req_name) {
          Some(i) =>
            for req in parsed.requirements {
              for sc in req.scenarios {
                model.requirements[i].scenarios.push(sc)
              }
            }
          None => ()
        }
      }
    }
    model
  })
  specs.sort_by((a, b) => @okf.lexical_compare(a.capability, b.capability))
  let changes = of_type(bundle, change_type).map(doc => {
    let name = doc.metadata().text("change").unwrap_or(doc.display_title())
    let archived = doc.metadata().text("state") == Some("archived")
    let same = (d : @okf.Document) => d.metadata().text("change") == Some(name)
    let design = of_type(bundle, design_type)
      .iter()
      .find_first(same)
      .map(d => d.body())
    let task_groups = match
      of_type(bundle, tasks_type).iter().find_first(same) {
      Some(d) => parse_tasks(d.prose_lines())
      None => []
    }
    let deltas = of_type(bundle, delta_type)
      .iter()
      .filter(same)
      .map(d => {
        parse_spec(
          d.metadata().text("capability").unwrap_or(""),
          d.prose_lines(),
        )
      })
      .collect()
    deltas.sort_by((a, b) => @okf.lexical_compare(a.capability, b.capability))
    { name, archived, proposal: Some(doc.body()), design, task_groups, deltas, }
  })
  changes.sort_by((a, b) => @okf.lexical_compare(a.name, b.name))
  { specs, changes, }
}

///|
fn zero_requirement(r : Requirement) -> Requirement {
  { ..r, line: 0, scenarios: r.scenarios.map(s => { ..s, line: 0, }), }
}

///|
fn zero_spec(s : SpecModel) -> SpecModel {
  {
    ..s,
    requirements: s.requirements.map(zero_requirement),
    deltas: s.deltas.map(d => {
      ..d,
      requirements: d.requirements.map(zero_requirement),
    }),
  }
}

///|
/// The view without line numbers, for comparing forms whose lines differ.
pub fn OpenSpecView::without_lines(self : OpenSpecView) -> OpenSpecView {
  {
    specs: self.specs.map(zero_spec),
    changes: self.changes.map(c => {
      ..c,
      deltas: c.deltas.map(zero_spec),
      task_groups: c.task_groups.map(g => {
        ..g,
        tasks: g.tasks.map(t => { ..t, line: 0, }),
      }),
    }),
  }
}

///|
pub extend Kind with Eq::{not_equal, equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
pub extend OpenSpecProfile with @moonrockz/okf.Profile::{
  name,
  options,
  relations,
  registers,
  templates,
  vocabulary,
  severities,
  reference_fields,
  bundle_keys,
  derive_metadata,
  rule_sets,
}
