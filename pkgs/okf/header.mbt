///|
/// The line ending that a text uses most, so that edits can reuse it.
pub(all) enum LineEnding {
  Lf
  CrLf
  Cr
} derive(Eq, Debug)

///|
pub fn LineEnding::text(self : LineEnding) -> String {
  match self {
    Lf => "\n"
    CrLf => "\r\n"
    Cr => "\r"
  }
}

///|
/// The line ending of the first line break in `text`, or `Lf` when there is none.
pub fn detect_line_ending(text : String) -> LineEnding {
  let n = text.length()
  for i in 0..<n {
    match text[i] {
      '\n' => return Lf
      '\r' => return if i + 1 < n && text[i + 1] == '\n' { CrLf } else { Cr }
      _ => ()
    }
  }
  Lf
}

///|
/// One line of a text, with its start offset and its line ending.
pub(all) struct Line {
  /// The line text without its line ending.
  text : String
  /// The UTF-16 offset of the first character of the line.
  start : Int32
  /// The line ending after the line, `""` for a last line without one.
  ending : String
} derive(Eq, Debug)

///|
/// Splits `text` into lines. LF, CRLF and CR all end a line. A final line
/// without a line ending is kept; an empty text has no lines.
pub fn split_lines(text : String) -> Array[Line] {
  let lines = []
  let n = text.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    let c = text[i]
    if c == '\n' || c == '\r' {
      let ending = if c == '\r' && i + 1 < n && text[i + 1] == '\n' {
        "\r\n"
      } else if c == '\r' {
        "\r"
      } else {
        "\n"
      }
      lines.push({ text: text[start:i].to_owned(), start, ending, })
      i += ending.length()
      start = i
    } else {
      i += 1
    }
  }
  if start < n {
    lines.push({ text: text[start:n].to_owned(), start, ending: "", })
  }
  lines
}

///|
/// How a document starts.
pub(all) enum HeaderShape {
  /// The document does not start with a `---` line.
  NoBlock
  /// A frontmatter block between `---` and a `---` or `...` line.
  Block(raw~ : String)
  /// A `---` first line with no closing line.
  Unterminated
} derive(Eq, Debug)

///|
/// The split of a document into its frontmatter block and its Markdown body.
pub(all) struct Header {
  shape : HeaderShape
  /// The text after the closing delimiter line, or the whole text without a block.
  body : String
  /// The UTF-16 offset of the body in the original text.
  body_offset : Int32
  /// The file line of the first body line, counted from 1.
  body_line : Int32
  /// True when the text starts with a byte order mark.
  bom : Bool
} derive(Eq, Debug)

///|
fn is_delimiter(line : String, marks : Array[String]) -> Bool {
  let trimmed = line.trim_end(chars=" \t").to_owned()
  marks.contains(trimmed)
}

///|
/// Splits `text` into a frontmatter block and a body, as OKF and
/// `moonrockz/mdc` read it: a first line `---` opens the block, and the next
/// `---` or `...` line closes it. A leading byte order mark is allowed.
pub fn split_header(text : String) -> Header {
  let bom = text.length() > 0 && text[0] == 0xFEFF
  let start = if bom { 1 } else { 0 }
  let content = text[start:].to_owned()
  let lines = split_lines(content)
  if lines.is_empty() || !is_delimiter(lines[0].text, ["---"]) {
    return {
      shape: NoBlock,
      body: content,
      body_offset: start,
      body_line: 1,
      bom,
    }
  }
  for i in 1..<lines.length() {
    if is_delimiter(lines[i].text, ["---", "..."]) {
      let raw_start = lines[1].start
      let raw_end = lines[i].start
      let raw = if i == 1 { "" } else { content[raw_start:raw_end].to_owned() }
      let body_start = lines[i].start +
        lines[i].text.length() +
        lines[i].ending.length()
      return {
        shape: Block(raw~),
        body: content[body_start:].to_owned(),
        body_offset: start + body_start,
        body_line: i + 2,
        bom,
      }
    }
  }
  { shape: Unterminated, body: content, body_offset: start, body_line: 1, bom, }
}

///|
/// One top-level key of a frontmatter block, located in the raw block text.
pub(all) struct RawEntry {
  key : String
  /// The text after `key:` on the key line, without a trailing comment.
  inline : String
  /// The 0-based index of the key line in the raw block.
  first_line : Int32
  /// The 0-based index of the last line that belongs to the value.
  last_line : Int32
} derive(Eq, Debug)

///|
fn is_continuation(line : String) -> Bool {
  if line.length() == 0 {
    return false
  }
  let c = line[0]
  c == ' ' || c == '\t' || line == "-" || line.has_prefix("- ")
}

///|
fn strip_comment(text : String) -> String {
  // A comment starts at `#` after white space, outside quotes.
  let mut quote : Char? = None
  let chars = text.to_array()
  for i, ch in chars {
    match quote {
      Some(q) => if ch == q { quote = None }
      None =>
        if ch == '"' || ch == '\'' {
          quote = Some(ch)
        } else if ch == '#' &&
          (i == 0 || chars[i - 1] == ' ' || chars[i - 1] == '\t') {
          return String::from_array(chars[:i]).trim_end(chars=" \t").to_owned()
        }
    }
  }
  text.trim_end(chars=" \t").to_owned()
}

///|
/// Parses a key line, for example `title: Revenue` or `"odd key": 1`.
fn parse_key_line(line : String) -> (String, String)? {
  if line.length() == 0 {
    return None
  }
  let c = line[0]
  if c == ' ' || c == '\t' || c == '#' || c == '-' {
    return None
  }
  if c == '"' || c == '\'' {
    let chars = line.to_array()
    let quote = chars[0]
    for i in 1..<chars.length() {
      if chars[i] == quote {
        let key = String::from_array(chars[1:i])
        let rest = String::from_array(chars[i + 1:])
        if rest.has_prefix(":") {
          return Some(
            (
              key,
              strip_comment(rest[1:].to_owned()).trim(chars=" \t").to_owned(),
            ),
          )
        }
        return None
      }
    }
    return None
  }
  match line.find(":") {
    Some(i) => {
      let after = line[i + 1:].to_owned()
      if after.length() > 0 && after[0] != ' ' && after[0] != '\t' {
        return None
      }
      let key = line[:i].trim_end(chars=" \t").to_owned()
      Some((key, strip_comment(after).trim(chars=" \t").to_owned()))
    }
    None => None
  }
}

///|
/// Finds each top-level key of a raw frontmatter block, in source order, with
/// the lines of its value. Trailing blank and comment lines do not belong to a value.
pub fn scan_entries(raw : String) -> Array[RawEntry] {
  let lines = split_lines(raw).map(l => l.text)
  let entries : Array[RawEntry] = []
  let mut i = 0
  while i < lines.length() {
    match parse_key_line(lines[i]) {
      Some((key, inline)) => {
        let mut last = i
        let mut j = i + 1
        while j < lines.length() {
          let line = lines[j]
          if is_continuation(line) {
            last = j
            j += 1
          } else if line.trim(chars=" \t").length() == 0 || line.has_prefix("#") {
            j += 1
          } else {
            break
          }
        }
        entries.push({ key, inline, first_line: i, last_line: last, })
        i = last + 1
      }
      None => i += 1
    }
  }
  entries
}

///|
pub extend LineEnding with Eq::{not_equal, equal}

///|
pub extend LineEnding with @debug.Debug::{to_repr}

///|
pub extend Line with Eq::{not_equal, equal}

///|
pub extend Line with @debug.Debug::{to_repr}

///|
pub extend HeaderShape with Eq::{not_equal, equal}

///|
pub extend HeaderShape with @debug.Debug::{to_repr}

///|
pub extend Header with Eq::{not_equal, equal}

///|
pub extend Header with @debug.Debug::{to_repr}

///|
pub extend RawEntry with Eq::{not_equal, equal}

///|
pub extend RawEntry with @debug.Debug::{to_repr}
