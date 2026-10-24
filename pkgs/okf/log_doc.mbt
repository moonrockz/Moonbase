///|
/// One `log.md` entry, such as `* **Update**: Added revenue metric.`
pub(all) struct LogEntry {
  /// The bold first word, such as `Update`, when it is present.
  label : String?
  text : String
  line : Int32
} derive(Eq, Debug)

///|
/// One dated `log.md` section.
pub(all) struct LogSection {
  /// The heading text, normally `YYYY-MM-DD`.
  date : String
  line : Int32
  entries : Array[LogEntry]
} derive(Eq, Debug)

///|
/// The parsed body of a `log.md` (OKF v0.2, section 9).
pub(all) struct LogModel {
  sections : Array[LogSection]
} derive(Eq, Debug)

///|
fn is_date_text(text : String) -> Bool {
  Instant::parse_date(text) is Some(_)
}

///|
fn parse_log_entry(line : String, number : Int32) -> LogEntry? {
  let t = line.trim_start(chars=" \t").to_owned()
  guard t.length() >= 2 && (t[0] == '*' || t[0] == '-') && t[1] == ' ' else {
    return None
  }
  let t = t[2:].trim(chars=" \t").to_owned()
  if t.has_prefix("**") {
    match t[2:].find("**") {
      Some(end) => {
        let label = t[2:2 + end].trim_end(chars=":").to_owned()
        let rest = t[4 + end:]
          .trim_start(chars=":")
          .trim(chars=" \t")
          .to_owned()
        return Some({ label: Some(label), text: rest, line: number, })
      }
      None => ()
    }
  }
  Some({ label: None, text: t, line: number, })
}

///|
/// Parses the body of a log document. Each `##` heading starts a section.
pub fn Document::log_model(self : Document) -> LogModel {
  let sections : Array[LogSection] = []
  for pair in body_lines(self) {
    let (number, line) = pair
    match parse_heading_line(line) {
      Some((2, text)) =>
        sections.push({ date: text, line: number, entries: [], })
      Some(_) => ()
      None =>
        match (sections.last(), parse_log_entry(line, number)) {
          (Some(section), Some(entry)) => section.entries.push(entry)
          _ => ()
        }
    }
  }
  { sections, }
}

///|
/// The first pair of sections whose dates are not newest first, if any.
pub fn LogModel::order_problem(self : LogModel) -> (LogSection, LogSection)? {
  for i in 1..<self.sections.length() {
    let a = self.sections[i - 1]
    let b = self.sections[i]
    if is_date_text(a.date) && is_date_text(b.date) && a.date < b.date {
      return Some((a, b))
    }
  }
  None
}

///|
/// The sections whose heading is not a `YYYY-MM-DD` date.
pub fn LogModel::undated_sections(self : LogModel) -> Array[LogSection] {
  self.sections.iter().filter(s => !is_date_text(s.date)).collect()
}

///|
/// A region of a document that starts at a marker comment, such as
/// `<!-- kb:sources -->`, and runs to the end of the document.
pub(all) struct Region {
  marker : String
  /// The text before the marker line, including the marker line.
  preamble : String
  /// The text after the marker line.
  content : String
  /// The file line of the marker.
  line : Int32
} derive(Eq, Debug)

///|
/// The comment form of a marker name: `<!-- name -->`.
pub fn marker_comment(name : String) -> String {
  "<!-- \{name} -->"
}

///|
/// Finds the region that the marker `<!-- name -->` starts.
pub fn find_region(text : String, name : String) -> Region? {
  let marker = marker_comment(name)
  for i, line in split_lines(text) {
    if line.text.trim(chars=" \t") == marker {
      let end = line.start + line.text.length() + line.ending.length()
      return Some({
        marker: name,
        preamble: text[:end].to_owned(),
        content: text[end:].to_owned(),
        line: i + 1,
      })
    }
  }
  None
}

///|
pub extend LogEntry with Eq::{not_equal, equal}

///|
pub extend LogEntry with @debug.Debug::{to_repr}

///|
pub extend LogSection with Eq::{not_equal, equal}

///|
pub extend LogSection with @debug.Debug::{to_repr}

///|
pub extend LogModel with Eq::{not_equal, equal}

///|
pub extend LogModel with @debug.Debug::{to_repr}

///|
pub extend Region with Eq::{not_equal, equal}

///|
pub extend Region with @debug.Debug::{to_repr}
