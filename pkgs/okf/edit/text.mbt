///|
/// The result of a text edit: the new text, and whether it differs from the input.
pub(all) struct EditResult {
  text : String
  changed : Bool
} derive(Eq, Debug)

///|
fn result_of(before : String, after : String) -> EditResult {
  { text: after, changed: before != after, }
}

///|
/// Raised when an edit cannot apply to a text.
pub(all) suberror EditError {
  /// The text has an unterminated frontmatter block.
  BrokenFrontmatter
  /// No index entry links to the destination.
  NoEntry(String)
  /// The marker comment is not in the text.
  NoRegion(String)
  /// A frontmatter key that is not a plain key: a letter, a digit or `_` first,
  /// then letters, digits, `_`, `.` or `-`.
  InvalidKey(String)
  /// A raw YAML value whose later lines are not indented, so it would add keys
  /// or close the frontmatter block.
  InvalidValue(key~ : String, value~ : String)
  /// A log date that is not a real calendar date in the form `YYYY-MM-DD`.
  InvalidDate(String)
  /// A text that must be one line, such as a log message or an index entry
  /// title, has a line break.
  LineBreak(field~ : String, text~ : String)
} derive(Eq, Debug)

///|
/// Checks that a text has no line break, so that it cannot add lines to a
/// log or an index.
fn check_one_line(field : String, text : String) -> Unit raise EditError {
  if text.contains("\n") || text.contains("\r") {
    raise LineBreak(field~, text~)
  }
}

///|
/// Checks a top-level frontmatter key, so that an edit cannot write a line that
/// YAML reads as another key or as the end of the block.
fn check_key(key : String) -> Unit raise EditError {
  // Only plain keys: a letter, a digit or `_` first, then letters, digits,
  // `_`, `.` or `-`. Quoted, anchored, tagged or padded keys read as another key.
  let first_ok = (c : Char) => {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_'
  }
  let ok = key.length() > 0 &&
    first_ok(key.get_char(0).unwrap_or(' ')) &&
    key.iter().all(c => first_ok(c) || c == '.' || c == '-')
  if !ok {
    raise InvalidKey(key)
  }
}

///|
/// Checks a raw YAML value: it is one line, or its later lines are indented
/// continuation lines.
fn check_value(key : String, value : String) -> Unit raise EditError {
  let lines = @okf.split_lines(value)
  for i, line in lines {
    if i == 0 {
      continue
    }
    let t = line.text
    if t.length() > 0 && !t.has_prefix(" ") && !t.has_prefix("\t") {
      raise InvalidValue(key~, value~)
    }
  }
}

///|
/// Checks that a date is a real calendar date in the form `YYYY-MM-DD`, with
/// the one shared rule `@okf.Instant::parse_date`.
fn check_date(date : String) -> Unit raise EditError {
  guard @okf.Instant::parse_date(date) is Some(_) else {
    raise InvalidDate(date)
  }
}

///|
/// Quotes a value for a YAML frontmatter line when it would change its meaning
/// unquoted: it contains special characters or line breaks, starts like a
/// sequence or mapping entry, has leading or trailing spaces, is empty, or
/// reads as null. Line breaks and tabs are escaped, so the value is kept exactly.
pub fn yaml_scalar(value : String) -> String {
  let special = ":#{}[]&*!|>'\"%@`,"
  let null_like = ["null", "Null", "NULL", "~"]
  let needs = value.length() == 0 ||
    value.has_prefix(" ") ||
    value.has_suffix(" ") ||
    value == "-" ||
    value == "?" ||
    value.has_prefix("- ") ||
    value.has_prefix("? ") ||
    null_like.contains(value) ||
    value
    .iter()
    .any(c => special.contains_char(c) || c == '\n' || c == '\r' || c == '\t')
  if needs {
    "\"" +
    value
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
    .replace_all(old="\n", new="\\n")
    .replace_all(old="\r", new="\\r")
    .replace_all(old="\t", new="\\t") +
    "\""
  } else {
    value
  }
}

///|
/// The parts of a text around its frontmatter block.
priv struct Located {
  lines : Array[@okf.Line]
  /// The index of the opening `---` line, or -1 without a block.
  open : Int32
  /// The index of the closing line.
  close : Int32
  ending : String
}

///|
fn locate(text : String) -> Located raise EditError {
  let lines = @okf.split_lines(text)
  let ending = @okf.detect_line_ending(text).text()
  let header = @okf.split_header(text)
  match header.shape {
    NoBlock => { lines, open: -1, close: -1, ending, }
    Unterminated => raise BrokenFrontmatter
    Block(..) => {
      // The closing line is the line before the first body line.
      let close = header.body_line - 2
      { lines, open: 0, close, ending, }
    }
  }
}

///|
fn join_lines(lines : Array[@okf.Line]) -> String {
  let out = StringBuilder()
  for l in lines {
    out.write_string(l.text)
    out.write_string(l.ending)
  }
  out.to_string()
}

///|
fn line(text : String, ending : String) -> @okf.Line {
  { text, start: 0, ending, }
}

///|
/// The raw block text between the delimiter lines.
fn raw_block(loc : Located) -> String {
  join_lines(loc.lines[loc.open + 1:loc.close].to_owned())
}

///|
/// Sets top-level frontmatter keys to raw YAML values (`Some`) or removes them
/// (`None`). A new key goes after the last non-blank frontmatter line. Every
/// other byte stays the same. Without a block, a new block is added.
pub fn set_raw_keys(
  text : String,
  updates : ArrayView[(String, String?)],
) -> EditResult raise EditError {
  for update in updates {
    check_key(update.0)
    match update.1 {
      Some(v) => check_value(update.0, v)
      None => ()
    }
  }
  let mut current = text
  for update in updates {
    let (key, value) = update
    let loc = locate(current)
    let lines = loc.lines.copy()
    if loc.open < 0 {
      match value {
        None => ()
        Some(v) => {
          let bom = current.length() > 0 && current[0] == 0xFEFF
          let rest = if bom { current[1:].to_owned() } else { current }
          let prefix = if bom { "\u{FEFF}" } else { "" }
          let e = loc.ending
          current = "\{prefix}---\{e}\{key}: \{v}\{e}---\{e}\{rest}"
        }
      }
      continue
    }
    let entries = @okf.scan_entries(raw_block(loc))
    match (entries.search_by(en => en.key == key), value) {
      (Some(i), Some(v)) => {
        let first = loc.open + 1 + entries[i].first_line
        let last = loc.open + 1 + entries[i].last_line
        let new_line = line("\{key}: \{v}", lines[last].ending)
        let out = lines[:first].to_owned()
        out.push(new_line)
        for l in lines[last + 1:] {
          out.push(l)
        }
        current = join_lines(out)
      }
      (Some(i), None) => {
        let first = loc.open + 1 + entries[i].first_line
        let last = loc.open + 1 + entries[i].last_line
        let out = lines[:first].to_owned()
        for l in lines[last + 1:] {
          out.push(l)
        }
        current = join_lines(out)
      }
      (None, Some(v)) => {
        let mut at = loc.close
        while at - 1 > loc.open &&
              lines[at - 1].text.trim(chars=" \t").length() == 0 {
          at -= 1
        }
        // The line before the insertion point may lack an ending when the
        // block was empty; a delimiter line always has one.
        let out = lines[:at].to_owned()
        out.push(line("\{key}: \{v}", loc.ending))
        for l in lines[at:] {
          out.push(l)
        }
        current = join_lines(out)
      }
      (None, None) => ()
    }
  }
  result_of(text, current)
}

///|
/// Sets a top-level frontmatter key to a scalar, quoted when YAML needs it.
pub fn set_key(
  text : String,
  key : String,
  value : String,
) -> EditResult raise EditError {
  set_raw_keys(text, [(key, Some(yaml_scalar(value)))])
}

///|
/// Sets a top-level frontmatter key to a list of scalars, in flow form.
pub fn set_list_key(
  text : String,
  key : String,
  values : ArrayView[String],
) -> EditResult raise EditError {
  let items = values.iter().map(yaml_scalar).collect().join(", ")
  set_raw_keys(text, [(key, Some("[\{items}]"))])
}

///|
/// Removes a top-level frontmatter key and its value lines.
pub fn remove_key(text : String, key : String) -> EditResult raise EditError {
  set_raw_keys(text, [(key, None)])
}

///|
/// The line of an index entry: `* [title](destination) - description`.
pub fn index_entry_line(
  title : String,
  destination : String,
  description? : String,
) -> String raise EditError {
  check_one_line("title", title)
  check_one_line("destination", destination)
  match description {
    Some(d) => check_one_line("description", d)
    None => ()
  }
  match description {
    Some(d) if d.length() > 0 => "* [\{title}](\{destination}) - \{d}"
    _ => "* [\{title}](\{destination})"
  }
}

///|
/// Adds an entry line to the index section with this heading, after its last
/// entry. Without the section, a `# heading` section is added at the end.
pub fn add_index_entry(
  text : String,
  section : String,
  entry : String,
) -> EditResult raise EditError {
  let loc = locate(text)
  let lines = loc.lines.copy()
  let e = loc.ending
  let body_start = if loc.open < 0 { 0 } else { loc.close + 1 }
  // Find the section heading and the end of the section.
  let mut heading_at = -1
  let mut level = 0
  let mut end = lines.length()
  let mut fence = false
  for i in body_start..<lines.length() {
    let t = lines[i].text.trim_start(chars=" ").to_owned()
    if t.has_prefix("```") || t.has_prefix("~~~") {
      fence = !fence
      continue
    }
    guard !fence else { continue }
    match heading_of(t) {
      Some((lv, h)) =>
        if heading_at < 0 && h == section {
          heading_at = i
          level = lv
        } else if heading_at >= 0 && lv <= level {
          end = i
          break
        }
      None => ()
    }
  }
  if heading_at < 0 {
    let mut base = join_lines(lines)
    if base.length() > 0 && !base.has_suffix("\n") && !base.has_suffix("\r") {
      base = base + e
    }
    let sep = if base.length() == 0 || base.has_suffix(e + e) { "" } else { e }
    return result_of(text, "\{base}\{sep}# \{section}\{e}\{e}\{entry}\{e}")
  }
  let mut last_entry = -1
  for i in (heading_at + 1)..<end {
    if @okf.parse_index_entry(lines[i].text) is Some(_) {
      last_entry = i
    }
  }
  let at = if last_entry >= 0 {
    last_entry + 1
    // After the heading and one blank line, when there is one.
  } else if heading_at + 1 < lines.length() &&
    lines[heading_at + 1].text.trim(chars=" \t").length() == 0 {
    heading_at + 2
  } else {
    heading_at + 1
  }
  let out = lines[:at].to_owned()
  if at > 0 && out[at - 1].ending == "" {
    out[at - 1] = { ..out[at - 1], ending: e, }
  }
  out.push(line(entry, e))
  for l in lines[at:] {
    out.push(l)
  }
  result_of(text, join_lines(out))
}

///|
fn heading_of(t : String) -> (Int32, String)? {
  let mut level = 0
  while level < t.length() && t[level] == '#' {
    level += 1
  }
  if level == 0 || level > 6 || (level < t.length() && t[level] != ' ') {
    None
  } else {
    Some(
      (
        level,
        t[level:]
        .trim(chars=" \t")
        .trim_end(chars="#")
        .trim(chars=" \t")
        .to_owned(),
      ),
    )
  }
}

///|
/// Changes the description of the entry that links to `destination`, and
/// keeps its link text. Raises `NoEntry` when no entry links there.
pub fn refresh_index_entry(
  text : String,
  destination : String,
  description : String,
) -> EditResult raise EditError {
  let lines = @okf.split_lines(text)
  let out = lines.copy()
  let mut found = false
  for i, l in lines {
    match @okf.parse_index_entry(l.text) {
      Some(entry) if entry.destination == destination => {
        found = true
        let trimmed = l.text.trim_start(chars=" \t").to_owned()
        let indent = l.text[:l.text.length() - trimmed.length()].to_owned()
        let marker = trimmed[0:1].to_owned()
        let tail = index_entry_line(entry.text, entry.destination, description~)[1:].to_owned()
        out[i] = { ..l, text: indent + marker + tail, }
      }
      _ => ()
    }
  }
  if !found {
    raise NoEntry(destination)
  }
  result_of(text, join_lines(out))
}

///|
/// Adds a log entry under the `## date` section. Without the section, it is
/// added in newest-first order. `label` gives the bold first word.
pub fn add_log_entry(
  text : String,
  date : String,
  message : String,
  label? : String,
) -> EditResult raise EditError {
  check_date(date)
  check_one_line("message", message)
  match label {
    Some(l) => check_one_line("label", l)
    None => ()
  }
  let loc = locate(text)
  let lines = loc.lines.copy()
  let e = loc.ending
  let entry = match label {
    Some(l) => "* **\{l}**: \{message}"
    None => "* \{message}"
  }
  let body_start = if loc.open < 0 { 0 } else { loc.close + 1 }
  let mut section_at = -1
  let mut insert_section_at = -1
  for i in body_start..<lines.length() {
    let t = lines[i].text
    if t.has_prefix("## ") {
      let d = t[3:].trim(chars=" \t").to_owned()
      if d == date {
        section_at = i
        break
      }
      if insert_section_at < 0 && @okf.lexical_compare(d, date) < 0 {
        insert_section_at = i
      }
    }
  }
  if section_at >= 0 {
    // After the last entry of the section, or after the heading.
    let mut at = section_at + 1
    let mut i = section_at + 1
    while i < lines.length() &&
          !lines[i].text.has_prefix("## ") &&
          !lines[i].text.has_prefix("# ") {
      let t = lines[i].text.trim_start(chars=" ")
      if t.has_prefix("* ") || t.has_prefix("- ") {
        at = i + 1
      } else if at == section_at + 1 && t.length() == 0 {
        at = i + 1
      }
      i += 1
    }
    let out = lines[:at].to_owned()
    if at > 0 && out[at - 1].ending == "" {
      out[at - 1] = { ..out[at - 1], ending: e, }
    }
    out.push(line(entry, e))
    for l in lines[at:] {
      out.push(l)
    }
    return result_of(text, join_lines(out))
  }
  let block = [line("## \{date}", e), line("", e), line(entry, e), line("", e)]
  if insert_section_at >= 0 {
    let out = lines[:insert_section_at].to_owned()
    for l in block {
      out.push(l)
    }
    for l in lines[insert_section_at:] {
      out.push(l)
    }
    return result_of(text, join_lines(out))
  }
  // No older section: add at the end.
  let mut base = join_lines(lines)
  if base.length() > 0 && !base.has_suffix("\n") && !base.has_suffix("\r") {
    base = base + e
  }
  let sep = if base.length() == 0 || base.has_suffix(e + e) { "" } else { e }
  result_of(text, "\{base}\{sep}## \{date}\{e}\{e}\{entry}\{e}")
}

///|
/// Replaces the content after the marker `<!-- name -->` and keeps the text
/// before it. Raises `NoRegion` when the marker is missing.
pub fn replace_region(
  text : String,
  name : String,
  content : String,
) -> EditResult raise EditError {
  match @okf.find_region(text, name) {
    Some(region) => result_of(text, region.preamble + content)
    None => raise NoRegion(name)
  }
}

///|
pub extend EditResult with Eq::{not_equal, equal}

///|
pub extend EditResult with @debug.Debug::{to_repr}

///|
pub extend EditError with Eq::{not_equal, equal}

///|
pub extend EditError with @debug.Debug::{to_repr}
