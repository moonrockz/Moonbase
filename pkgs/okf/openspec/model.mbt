///|
/// One OpenSpec scenario: `#### Scenario: name` with its WHEN, THEN and AND clauses.
pub(all) struct Scenario {
  name : String
  when_ : Array[String]
  then_ : Array[String]
  line : Int32
} derive(Eq, Debug)

///|
/// One OpenSpec requirement: `### Requirement: name`, its text and its scenarios.
pub(all) struct Requirement {
  name : String
  text : String
  scenarios : Array[Scenario]
  line : Int32
} derive(Eq, Debug)

///|
/// A delta operation of a change spec.
pub(all) enum DeltaOp {
  Added
  Modified
  Removed
  Renamed
} derive(Eq, Debug)

///|
/// One delta section: `## ADDED Requirements` and so on.
pub(all) struct DeltaSection {
  op : DeltaOp
  requirements : Array[Requirement]
  /// For `RENAMED`: (from, to) names.
  renames : Array[(String, String)]
} derive(Eq, Debug)

///|
/// The structured content of one spec file: a main specification, or a delta.
pub(all) struct SpecModel {
  capability : String
  purpose : String?
  /// The requirements of a main spec (`## Requirements`).
  requirements : Array[Requirement]
  /// The delta sections of a change spec.
  deltas : Array[DeltaSection]
} derive(Eq, Debug)

///|
/// One task of a `tasks.md`: `- [ ] 1.1 text`.
pub(all) struct Task {
  number : String
  text : String
  done : Bool
  line : Int32
} derive(Eq, Debug)

///|
/// One `## N. Group` of a `tasks.md`.
pub(all) struct TaskGroup {
  heading : String
  tasks : Array[Task]
} derive(Eq, Debug)

///|
/// One OpenSpec change.
pub(all) struct Change {
  name : String
  archived : Bool
  proposal : String?
  design : String?
  task_groups : Array[TaskGroup]
  deltas : Array[SpecModel]
} derive(Eq, Debug)

///|
/// The structured view of OpenSpec content.
pub(all) struct OpenSpecView {
  specs : Array[SpecModel]
  changes : Array[Change]
} derive(Eq, Debug)

///|
fn heading(line : String) -> (Int32, String)? {
  let t = line.trim_start(chars=" ").to_owned()
  let mut level = 0
  while level < t.length() && t[level] == '#' {
    level += 1
  }
  if level == 0 || level > 6 || (level < t.length() && t[level] != ' ') {
    None
  } else {
    Some((level, t[level:].trim(chars=" \t").to_owned()))
  }
}

///|
fn after_prefix(text : String, prefix : String) -> String? {
  if text.has_prefix(prefix) {
    Some(text[prefix.length():].trim(chars=" \t").to_owned())
  } else {
    None
  }
}

///|
/// A clause bullet: `- **WHEN** text` gives ("WHEN", "text").
fn clause(line : String) -> (String, String)? {
  let t = line.trim(chars=" \t").to_owned()
  guard t.has_prefix("- **") || t.has_prefix("* **") else { return None }
  let rest = t[4:].to_owned()
  guard rest.find("**") is Some(end) else { return None }
  let word = rest[:end].trim_end(chars=":").to_owned().to_upper()
  Some((word, rest[end + 2:].trim_start(chars=": \t").to_owned()))
}

///|
fn delta_op(text : String) -> DeltaOp? {
  match text.to_upper() {
    "ADDED REQUIREMENTS" => Some(Added)
    "MODIFIED REQUIREMENTS" => Some(Modified)
    "REMOVED REQUIREMENTS" => Some(Removed)
    "RENAMED REQUIREMENTS" => Some(Renamed)
    _ => None
  }
}

///|
fn requirement_name(text : String) -> String {
  let t = text.trim(chars=" \t`").to_owned()
  match after_prefix(t, "### Requirement:") {
    Some(n) => n
    None => after_prefix(t, "Requirement:").unwrap_or(t)
  }
}

///|
/// Parses an OpenSpec spec body (main or delta) from (file line, text) pairs.
pub fn parse_spec(
  capability : String,
  lines : ArrayView[(Int32, String)],
) -> SpecModel {
  let requirements : Array[Requirement] = []
  let deltas : Array[DeltaSection] = []
  let mut purpose : String? = None
  let mut in_purpose = false
  let purpose_lines : Array[String] = []
  let mut current_delta : DeltaSection? = None
  let mut current_req : Requirement? = None
  let mut current_scenario : Scenario? = None
  let req_text : Array[String] = []
  let mut last_clause = ""
  let flush_scenario = () => {
    match (current_scenario, current_req) {
      (Some(s), Some(r)) => r.scenarios.push(s)
      _ => ()
    }
    current_scenario = None
  }
  let flush_req = () => {
    flush_scenario()
    match current_req {
      Some(r) => {
        let r = { ..r, text: req_text.join("\n").trim(chars="\n ").to_owned(), }
        match current_delta {
          Some(d) => d.requirements.push(r)
          None => requirements.push(r)
        }
      }
      None => ()
    }
    current_req = None
    req_text.clear()
  }
  for pair in lines {
    let (number, line) = pair
    match heading(line) {
      Some((2, text)) => {
        flush_req()
        if in_purpose {
          purpose = Some(purpose_lines.join("\n").trim(chars="\n ").to_owned())
          in_purpose = false
        }
        match delta_op(text) {
          Some(op) => {
            let d = { op, requirements: [], renames: [], }
            deltas.push(d)
            current_delta = Some(d)
          }
          None => {
            current_delta = None
            if text.to_lower() == "purpose" {
              in_purpose = true
            }
          }
        }
      }
      Some((3, text)) if text.has_prefix("Requirement:") => {
        flush_req()
        current_req = Some({
          name: text["Requirement:".length():].trim(chars=" \t").to_owned(),
          text: "",
          scenarios: [],
          line: number,
        })
      }
      Some((4, text)) if text.has_prefix("Scenario:") => {
        flush_scenario()
        current_scenario = Some({
          name: text["Scenario:".length():].trim(chars=" \t").to_owned(),
          when_: [],
          then_: [],
          line: number,
        })
      }
      Some((1, _)) => flush_req()
      _ => {
        if in_purpose {
          purpose_lines.push(line)
          continue
        }
        match current_delta {
          Some(d) if d.op is Renamed => {
            let t = line.trim(chars=" \t-").to_owned()
            match after_prefix(t, "FROM:") {
              Some(from) => d.renames.push((requirement_name(from), ""))
              None =>
                match (after_prefix(t, "TO:"), d.renames.last()) {
                  (Some(to), Some(last)) if last.1 == "" =>
                    d.renames[d.renames.length() - 1] = (
                      last.0,
                      requirement_name(to),
                    )
                  _ => ()
                }
            }
          }
          _ => ()
        }
        match current_scenario {
          Some(s) =>
            match clause(line) {
              Some((word, text)) => {
                let word = if word == "AND" { last_clause } else { word }
                if word == "WHEN" || word == "GIVEN" {
                  s.when_.push(text)
                  last_clause = "WHEN"
                } else if word == "THEN" {
                  s.then_.push(text)
                  last_clause = "THEN"
                }
              }
              None => ()
            }
          None => if current_req is Some(_) { req_text.push(line) }
        }
      }
    }
  }
  flush_req()
  if in_purpose {
    purpose = Some(purpose_lines.join("\n").trim(chars="\n ").to_owned())
  }
  { capability, purpose, requirements, deltas, }
}

///|
/// Parses a `tasks.md` body from (file line, text) pairs.
pub fn parse_tasks(lines : ArrayView[(Int32, String)]) -> Array[TaskGroup] {
  let groups : Array[TaskGroup] = []
  for pair in lines {
    let (number, line) = pair
    match heading(line) {
      Some((2, text)) => groups.push({ heading: text, tasks: [], })
      _ => {
        let t = line.trim_start(chars=" \t").to_owned()
        guard t.length() > 6 &&
          (t.has_prefix("- [") || t.has_prefix("* [")) &&
          t[4] == ']' else {
          continue
        }
        let mark = t[3:4].to_owned()
        let done = mark.trim(chars=" ").to_lower() == "x"
        let rest = t[5:].trim(chars=" \t").to_owned()
        let (num, text) = match rest.find(" ") {
          Some(i) if rest[:i]
            .iter()
            .all(c => (c >= '0' && c <= '9') || c == '.') =>
            (rest[:i].to_owned(), rest[i + 1:].trim(chars=" \t").to_owned())
          _ => ("", rest)
        }
        let task = { number: num, text, done, line: number, }
        match groups.last() {
          Some(g) => g.tasks.push(task)
          None => groups.push({ heading: "", tasks: [task], })
        }
      }
    }
  }
  groups
}

///|
pub extend Scenario with Eq::{not_equal, equal}

///|
pub extend Scenario with @debug.Debug::{to_repr}

///|
pub extend Requirement with Eq::{not_equal, equal}

///|
pub extend Requirement with @debug.Debug::{to_repr}

///|
pub extend DeltaOp with Eq::{not_equal, equal}

///|
pub extend DeltaOp with @debug.Debug::{to_repr}

///|
pub extend DeltaSection with Eq::{not_equal, equal}

///|
pub extend DeltaSection with @debug.Debug::{to_repr}

///|
pub extend SpecModel with Eq::{not_equal, equal}

///|
pub extend SpecModel with @debug.Debug::{to_repr}

///|
pub extend Task with Eq::{not_equal, equal}

///|
pub extend Task with @debug.Debug::{to_repr}

///|
pub extend TaskGroup with Eq::{not_equal, equal}

///|
pub extend TaskGroup with @debug.Debug::{to_repr}

///|
pub extend Change with Eq::{not_equal, equal}

///|
pub extend Change with @debug.Debug::{to_repr}

///|
pub extend OpenSpecView with Eq::{not_equal, equal}

///|
pub extend OpenSpecView with @debug.Debug::{to_repr}
