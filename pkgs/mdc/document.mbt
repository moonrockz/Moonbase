///|
/// An immutable MDC document. Cmark locations are relative to `body()`.
/// Add `body_offset()` to cmark string offsets and `body_line() - 1` to line numbers
/// to locate Markdown in the original input. Offsets count UTF-16 code units.
struct Document {
  frontmatter : Frontmatter?
  markdown : @cmark.Doc
  body : String
  body_offset : Int32
  body_line : Int32
} derive(Debug)

///|
pub extend Document with @debug.Debug::{to_repr}

///|
pub fn Document::frontmatter(self : Document) -> Frontmatter? {
  self.frontmatter
}

///|
pub fn Document::body(self : Document) -> String {
  self.body
}

///|
pub fn Document::body_offset(self : Document) -> Int32 {
  self.body_offset
}

///|
pub fn Document::body_line(self : Document) -> Int32 {
  self.body_line
}

///|
/// An owned cmark copy for rendering or transformation. Its mutable maps and
/// sequences share no storage with the document or its traversal views.
pub fn Document::to_cmark(self : Document) -> @cmark.Doc {
  copy_doc(self.markdown)
}

///|
pub fn Document::root(self : Document) -> Node {
  Node::Document(self)
}

///|
pub(all) suberror ParseError {
  UnterminatedFrontmatter
  InvalidFrontmatter(line~ : Int32, column~ : Int32, message~ : String)
} derive(Debug)

///|
pub extend ParseError with @debug.Debug::{to_repr}

///|
// Return the line text and the offset after its newline, accepting LF, CRLF
// and CR. Delimiters may have trailing horizontal whitespace.
fn line_at(source : String, start : Int32) -> (String, Int32) {
  let mut end = start
  while end < source.length() {
    let c = source.code_unit_at(end)
    if c == 10 || c == 13 {
      break
    }
    end += 1
  }
  let text = source[start:end].to_owned()
  let mut next = end
  if next < source.length() {
    next += 1
    if source.code_unit_at(end) == 13 &&
      next < source.length() &&
      source.code_unit_at(next) == 10 {
      next += 1
    }
  }
  (text, next)
}

///|
/// Parse CommonMark with an optional leading YAML mapping between `---` lines.
/// `...` also closes frontmatter. A UTF-8 BOM decoded as U+FEFF is accepted.
/// An opener must be the first line, with no leading whitespace. An empty
/// payload is an empty mapping. Malformed YAML and non-mappings are errors.
/// Cmark's `strict` option defaults to true. Set it to false for extensions.
pub fn Document::Document(
  source : String,
  strict~ : Bool = true,
  layout~ : Bool = true,
  locs~ : Bool = true,
  file~ : String = "",
) -> Document raise ParseError {
  let start = if source.has_prefix("\u{FEFF}") { 1 } else { 0 }
  let (first, after_first) = line_at(source, start)
  let mut body_offset = start
  let mut body_line = 1
  let frontmatter = if first.trim_end(chars=" \t") == "---" {
    let mut offset = after_first
    let mut line = 2
    let mut end = None
    while offset < source.length() {
      let (text, next) = line_at(source, offset)
      let delimiter = text.trim_end(chars=" \t")
      if delimiter == "---" || delimiter == "..." {
        end = Some(offset)
        body_offset = next
        body_line = if next > offset + text.length() { line + 1 } else { line }
        break
      }
      offset = next
      line += 1
    }
    guard end is Some(end) else { raise UnterminatedFrontmatter }
    let frontmatter = Frontmatter::Frontmatter(
      source[after_first:end].to_owned(),
    ) catch {
      InvalidFrontmatter(line~, column~, message~) =>
        raise InvalidFrontmatter(line=line + 1, column~, message~)
      error => raise error
    }
    Some(frontmatter)
  } else {
    None
  }
  let body = source[body_offset:].to_owned()
  let markdown = @cmark.Doc::from_string(body, strict~, layout~, locs~, file~)
  { frontmatter, markdown, body, body_offset, body_line, }
}

///|
/// Parse an immutable document. Equivalent to `Document::Document`.
pub fn parse(
  source : String,
  strict~ : Bool = true,
  layout~ : Bool = true,
  locs~ : Bool = true,
  file~ : String = "",
) -> Document raise ParseError {
  Document::Document(source, strict~, layout~, locs~, file~)
}
