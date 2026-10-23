///|
/// A filter on concepts. Text comparison ignores letter case.
pub(all) enum Filter {
  /// `type` equals the value.
  TypeIs(String)
  /// The effective status equals the value.
  StatusIs(String)
  /// `tags` contains the value.
  HasTag(String)
  /// The bundle label or name equals the value.
  InBundle(String)
  /// The frontmatter key has the value (as text, or as one item of a list).
  FieldIs(String, String)
} derive(Eq, Debug)

///|
/// True when the concept matches the filter.
pub fn Filter::matches(self : Filter, bundle : Bundle, doc : Document) -> Bool {
  let meta = doc.metadata()
  let eq = (a : String, b : String) => a.to_lower() == b.to_lower()
  match self {
    TypeIs(t) =>
      match meta.concept_type() {
        Some(v) => eq(v, t)
        None => false
      }
    StatusIs(s) =>
      match meta.effective_status(options=bundle.options()) {
        Some(v) => eq(v.to_string(), s)
        None => false
      }
    HasTag(tag) => meta.tags().any(v => eq(v, tag))
    InBundle(label) => eq(bundle.label(), label) || eq(bundle.name(), label)
    FieldIs(key, value) => meta.texts(key).any(v => eq(v, value))
  }
}

///|
/// The concepts that match every filter.
pub fn Knowledge::filter(
  self : Knowledge,
  filters : ArrayView[Filter],
) -> Array[(Bundle, Document)] {
  self
  .concepts()
  .iter()
  .filter(pair => filters.iter().all(f => f.matches(pair.0, pair.1)))
  .collect()
}

///|
/// The values of a facet over the concepts that match `filters`, with their
/// counts, most frequent first. The keys `type`, `status` and `tags` use the
/// typed fields; other keys read the frontmatter as text.
pub fn Knowledge::facet(
  self : Knowledge,
  key : String,
  filters~ : ArrayView[Filter] = [],
) -> Array[(String, Int32)] {
  let counts : Map[String, Int32] = Map([])
  for pair in self.filter(filters) {
    let (bundle, doc) = pair
    let meta = doc.metadata()
    let values = match key {
      "type" =>
        match meta.concept_type() {
          Some(t) => [t]
          None => []
        }
      "status" =>
        match meta.effective_status(options=bundle.options()) {
          Some(s) => [s.to_string()]
          None => []
        }
      "tags" => meta.tags()
      "bundle" => [bundle.label()]
      _ => meta.texts(key)
    }
    for v in values {
      counts[v] = counts.get(v).unwrap_or(0) + 1
    }
  }
  let out = counts.iter().collect()
  out.sort_by((a, b) => {
    if a.1 != b.1 {
      b.1.compare(a.1)
    } else {
      lexical_compare(a.0, b.0)
    }
  })
  out
}

///|
/// One result of a text scan.
pub(all) struct ScanHit {
  key : DocKey
  /// The fields that contain the text: `title`, `description`, `type`, `tags` or `path`.
  fields : Array[String]
  /// The body lines that contain the text, as (file line, line text).
  lines : Array[(Int32, String)]
} derive(Eq, Debug)

///|
/// Finds the concepts whose title, description, type, tags or path contain
/// `text`, ignoring letter case. With `bodies=true`, body lines count too.
pub fn Knowledge::scan(
  self : Knowledge,
  text : String,
  bodies~ : Bool = false,
  filters~ : ArrayView[Filter] = [],
) -> Array[ScanHit] {
  let needle = text.to_lower()
  let out = []
  for pair in self.filter(filters) {
    let (bundle, doc) = pair
    let meta = doc.metadata()
    let fields = []
    if doc.display_title().to_lower().contains(needle) {
      fields.push("title")
    }
    if meta.description().unwrap_or("").to_lower().contains(needle) {
      fields.push("description")
    }
    if meta.concept_type().unwrap_or("").to_lower().contains(needle) {
      fields.push("type")
    }
    if meta.tags().any(t => t.to_lower().contains(needle)) {
      fields.push("tags")
    }
    if doc.path().to_string().to_lower().contains(needle) {
      fields.push("path")
    }
    let lines = []
    if bodies {
      for i, line in split_lines(doc.body()) {
        if line.text.to_lower().contains(needle) {
          lines.push((doc.body_line() + i, line.text))
        }
      }
    }
    if !fields.is_empty() || !lines.is_empty() {
      out.push({ key: DocKey::of(bundle, doc), fields, lines, })
    }
  }
  out
}

///|
/// Finds a document by bundle and path. Without an exact match, the documents
/// whose path ends with `path` match. `bundle` narrows the search to one bundle.
pub fn Knowledge::find_document(
  self : Knowledge,
  path : String,
  bundle? : String,
) -> Lookup[(Bundle, Document)] {
  let bundles = match bundle {
    Some(label) =>
      match self.bundle(label) {
        Found(b) => [b]
        Ambiguous(list) => list
        NotFound => []
      }
    None => self.bundles.iter().collect()
  }
  let exact = []
  try BundlePath(path) catch {
    _ => ()
  } noraise {
    p =>
      for b in bundles {
        match b.document(p) {
          Some(d) => exact.push((b, d))
          None => ()
        }
      }
  }
  if !exact.is_empty() {
    return lookup_of(exact)
  }
  let suffix = []
  for b in bundles {
    for d in b.documents() {
      if d.path().ends_with(path) {
        suffix.push((b, d))
      }
    }
  }
  lookup_of(suffix)
}

///|
/// One heading of a document outline.
pub(all) struct Heading {
  level : Int32
  text : String
  slug : String
  line : Int32
} derive(Eq, Debug)

///|
/// A GitHub-style slug: lower case, letters, digits, `-` and `_`, with
/// spaces as `-`.
pub fn slugify(text : String) -> String {
  let out = StringBuilder()
  for c in text.to_lower() {
    if (c >= 'a' && c <= 'z') ||
      (c >= '0' && c <= '9') ||
      c == '-' ||
      c == '_' ||
      c.to_int() > 127 {
      out.write_char(c)
    } else if c == ' ' {
      out.write_char('-')
    }
  }
  out.to_string()
}

///|
/// The headings of the body, with levels, slugs and file lines. Lines in code
/// that start with `#` are not headings. Repeated slugs get `-1`, `-2` and so on.
pub fn Document::outline(self : Document) -> Array[Heading] {
  guard self.markdown is Some(md) else { return [] }
  let out = []
  let seen : Map[String, Int32] = Map([])
  @mdc.walk(md.root(), node => {
    match node {
      Block(view) =>
        match view.kind() {
          Heading(level~) => {
            let text = match view.to_cmark() {
              Heading(h) => plain_text(h.v.inline)
              _ => ""
            }
            let base = slugify(text)
            let slug = match seen.get(base) {
              Some(n) => {
                seen[base] = n + 1
                "\{base}-\{n}"
              }
              None => {
                seen[base] = 1
                base
              }
            }
            out.push({
              level,
              text,
              slug,
              line: self.file_line(line_of_loc(view.location())),
            })
            return SkipChildren
          }
          CodeBlock => return SkipChildren
          _ => ()
        }
      _ => ()
    }
    Continue
  })
  out
}

///|
/// One fenced or indented code block.
pub(all) struct CodeBlock {
  language : String?
  code : String
  line : Int32
} derive(Eq, Debug)

///|
/// The code blocks of the body, in order.
pub fn Document::code_blocks(self : Document) -> Array[CodeBlock] {
  guard self.markdown is Some(md) else { return [] }
  let out = []
  @mdc.walk(md.root(), node => {
    match node {
      Block(view) if view.kind() is CodeBlock =>
        match view.to_cmark() {
          CodeBlock(node) => {
            let language = match node.v.info_string {
              Some(info) =>
                match @cmark.CodeBlock::language_of_info_string(info.v) {
                  Some((lang, _)) => Some(lang)
                  None => None
                }
              None => None
            }
            let code = node.v.code.fold(init=[], (acc : Array[String], l) => {
              acc.push(l.v)
              acc
            })
            out.push({
              language,
              code: code.join("\n"),
              line: self.file_line(line_of_loc(view.location())),
            })
          }
          _ => ()
        }
      _ => ()
    }
    Continue
  })
  out
}

///|
/// The content under one heading, up to the next heading of the same or a higher level.
pub(all) struct SectionContent {
  heading : Heading
  /// The raw Markdown lines of the section, without the heading line.
  text : String
  code_blocks : Array[CodeBlock]
} derive(Eq, Debug)

///|
/// The section under the first heading with this text, ignoring letter case.
pub fn Document::section(self : Document, heading : String) -> SectionContent? {
  let outline = self.outline()
  guard outline.search_by(h => h.text.to_lower() == heading.to_lower())
    is Some(i) else {
    return None
  }
  let h = outline[i]
  let mut end_line = 2147483647
  for j in (i + 1)..<outline.length() {
    if outline[j].level <= h.level {
      end_line = outline[j].line
      break
    }
  }
  let lines = []
  for k, line in split_lines(self.body()) {
    let number = self.body_line() + k
    if number > h.line && number < end_line {
      lines.push(line.text)
    }
  }
  let code_blocks = self
    .code_blocks()
    .iter()
    .filter(c => c.line > h.line && c.line < end_line)
    .collect()
  Some({ heading: h, text: lines.join("\n"), code_blocks, })
}

///|
pub extend Filter with Eq::{not_equal, equal}

///|
pub extend Filter with @debug.Debug::{to_repr}

///|
pub extend ScanHit with Eq::{not_equal, equal}

///|
pub extend ScanHit with @debug.Debug::{to_repr}

///|
pub extend Heading with Eq::{not_equal, equal}

///|
pub extend Heading with @debug.Debug::{to_repr}

///|
pub extend CodeBlock with Eq::{not_equal, equal}

///|
pub extend CodeBlock with @debug.Debug::{to_repr}

///|
pub extend SectionContent with Eq::{not_equal, equal}

///|
pub extend SectionContent with @debug.Debug::{to_repr}
