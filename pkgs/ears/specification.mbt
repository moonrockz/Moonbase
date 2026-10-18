///|
/// A half-open UTF-16 range in the original input, with a one-based start
/// line and column. Markdown ranges cover the paragraph, including markup.
struct SourceSpan {
  start : Int32
  end : Int32
  line : Int32
  column : Int32
} derive(Eq, Debug)

///|
pub fn SourceSpan::start(self : SourceSpan) -> Int32 {
  self.start
}

///|
pub fn SourceSpan::end(self : SourceSpan) -> Int32 {
  self.end
}

///|
pub fn SourceSpan::line(self : SourceSpan) -> Int32 {
  self.line
}

///|
pub fn SourceSpan::column(self : SourceSpan) -> Int32 {
  self.column
}

///|
/// Markdown paths resolve against the retained MDC document. Locations are
/// absent if that document was parsed with `locs=false`.
pub enum Origin {
  Text(SourceSpan)
  Markdown(path~ : @mdc.NodePath, span~ : SourceSpan?)
} derive(Eq, Debug)

///|
struct Occurrence {
  requirement : Requirement
  origin : Origin
} derive(Eq, Debug)

///|
pub fn Occurrence::requirement(self : Occurrence) -> Requirement {
  self.requirement
}

///|
pub fn Occurrence::origin(self : Occurrence) -> Origin {
  self.origin
}

///|
struct Diagnostic {
  text : String
  error : ParseError
  origin : Origin
} derive(Eq, Debug)

///|
pub fn Diagnostic::text(self : Diagnostic) -> String {
  self.text
}

///|
pub fn Diagnostic::error(self : Diagnostic) -> ParseError {
  self.error
}

///|
pub fn Diagnostic::origin(self : Diagnostic) -> Origin {
  self.origin
}

///|
/// An immutable extraction result. Syntax errors do not discard valid siblings.
/// The Markdown constructor retains its MDC document and frontmatter.
struct Specification {
  requirements : ReadOnlyArray[Occurrence]
  diagnostics : ReadOnlyArray[Diagnostic]
  document : @mdc.Document?
} derive(Debug)

///|
pub fn Specification::requirements(
  self : Specification,
) -> ReadOnlyArray[Occurrence] {
  self.requirements
}

///|
pub fn Specification::diagnostics(
  self : Specification,
) -> ReadOnlyArray[Diagnostic] {
  self.diagnostics
}

///|
pub fn Specification::document(self : Specification) -> @mdc.Document? {
  self.document
}

///|
fn collect_candidate(
  text : String,
  origin : Origin,
  requirements : Array[Occurrence],
  diagnostics : Array[Diagnostic],
) -> Unit {
  let requirement = Requirement::Requirement(text) catch {
    error => {
      diagnostics.push({ text, error, origin, })
      return
    }
  }
  requirements.push({ requirement, origin, })
}

///|
/// Parse one requirement per nonblank line. Every nonblank line is checked.
/// Accept LF, CRLF, CR and a leading BOM. Spans exclude indentation/newlines.
pub fn parse_text(source : String) -> Specification {
  let requirements = []
  let diagnostics = []
  let mut offset = if source.has_prefix("\u{FEFF}") { 1 } else { 0 }
  let mut line = 1
  let mut line_start = 0
  while offset < source.length() {
    let mut end = offset
    while end < source.length() &&
          source.code_unit_at(end) != 10 &&
          source.code_unit_at(end) != 13 {
      end += 1
    }
    let mut first = offset
    let mut last = end
    while first < last && is_space(source.code_unit_at(first)) {
      first += 1
    }
    while last > first && is_space(source.code_unit_at(last - 1)) {
      last -= 1
    }
    if first < last {
      let span = SourceSpan::{
        start: first,
        end: last,
        line,
        column: first - line_start + 1,
      }
      collect_candidate(
        source[first:last].to_owned(),
        Text(span),
        requirements,
        diagnostics,
      )
    }
    offset = end
    if offset < source.length() {
      offset += 1
      if source.code_unit_at(end) == 13 &&
        offset < source.length() &&
        source.code_unit_at(offset) == 10 {
        offset += 1
      }
    }
    line += 1
    line_start = offset
  }
  {
    requirements: ReadOnlyArray::from_array(requirements[:]),
    diagnostics: ReadOnlyArray::from_array(diagnostics[:]),
    document: None,
  }
}

///|
pub extend SourceSpan with Eq::{equal, not_equal}

///|
pub extend SourceSpan with @debug.Debug::{to_repr}

///|
pub extend Origin with Eq::{equal, not_equal}

///|
pub extend Origin with @debug.Debug::{to_repr}

///|
pub extend Occurrence with Eq::{equal, not_equal}

///|
pub extend Occurrence with @debug.Debug::{to_repr}

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
pub extend Specification with @debug.Debug::{to_repr}
