///|
/// The kind of an OKF document, from its file name (OKF v0.2, section 3.1).
pub(all) enum DocKind {
  /// The `index.md` at the bundle root.
  RootIndex
  /// An `index.md` below the bundle root.
  SubIndex
  /// A `log.md` file.
  Log
  /// Any other Markdown file.
  Concept
} derive(Eq, Debug)

///|
/// The kind of the Markdown file at `path`.
pub fn kind_of(path : BundlePath) -> DocKind {
  match path.name().to_lower() {
    "index.md" => if path.depth() == 0 { RootIndex } else { SubIndex }
    "log.md" => Log
    _ => Concept
  }
}

///|
/// True when `kind` is an index.
pub fn DocKind::is_index(self : DocKind) -> Bool {
  self is (RootIndex | SubIndex)
}

///|
/// One Markdown document of a bundle, read once and immutable.
struct Document {
  path : BundlePath
  store_path : StorePath
  kind : DocKind
  text : String
  header : Header
  written : Metadata?
  error : MetadataError?
  derived : Metadata?
  markdown : @mdc.Document?
}

///|
/// Parses the Markdown body with `moonrockz/mdc`. A blank first line is added
/// so that a body that starts with `---` is never read as frontmatter.
fn parse_markdown(body : String) -> @mdc.Document? {
  try @mdc.parse("\n" + body, strict=false, layout=true, locs=true) catch {
    _ => None
  } noraise {
    doc => Some(doc)
  }
}

///|
/// Reads one document. Frontmatter errors are kept as data.
pub fn Document::Document(
  path : BundlePath,
  store_path : StorePath,
  text : String,
) -> Document {
  let header = split_header(text)
  let (written, error) = match header.shape {
    NoBlock => (None, None)
    Unterminated => (None, Some(MetadataError::Unterminated))
    Block(raw~) =>
      try Metadata(raw, first_line=2) catch {
        e => (None, Some(e))
      } noraise {
        m => (Some(m), None)
      }
  }
  {
    path,
    store_path,
    kind: kind_of(path),
    text,
    header,
    written,
    error,
    derived: None,
    markdown: parse_markdown(header.body),
  }
}

///|
/// A copy with derived metadata, for a document without frontmatter.
pub fn Document::with_derived(self : Document, fields : Fields) -> Document {
  { ..self, derived: Some(Metadata::of_fields(fields)), }
}

///|
pub fn Document::path(self : Document) -> BundlePath {
  self.path
}

///|
pub fn Document::store_path(self : Document) -> StorePath {
  self.store_path
}

///|
pub fn Document::kind(self : Document) -> DocKind {
  self.kind
}

///|
/// The full source text.
pub fn Document::text(self : Document) -> String {
  self.text
}

///|
/// The Markdown body after the frontmatter block.
pub fn Document::body(self : Document) -> String {
  self.header.body
}

///|
/// The file line of the first body line, counted from 1.
pub fn Document::body_line(self : Document) -> Int32 {
  self.header.body_line
}

///|
/// The shape of the start of the document.
pub fn Document::header(self : Document) -> Header {
  self.header
}

///|
/// True when the document starts with a frontmatter block, valid or not.
pub fn Document::has_frontmatter_block(self : Document) -> Bool {
  !(self.header.shape is NoBlock)
}

///|
/// The written frontmatter, when it is valid.
pub fn Document::written_metadata(self : Document) -> Metadata? {
  self.written
}

///|
/// The frontmatter error, when the block is invalid.
pub fn Document::metadata_error(self : Document) -> MetadataError? {
  self.error
}

///|
/// The metadata that profiles derived for a document without frontmatter.
pub fn Document::derived_metadata(self : Document) -> Metadata? {
  self.derived
}

///|
/// The written metadata, else the derived metadata, else empty metadata.
pub fn Document::metadata(self : Document) -> Metadata {
  match (self.written, self.derived) {
    (Some(m), _) => m
    (None, Some(m)) => m
    (None, None) => Metadata::empty()
  }
}

///|
/// True when the metadata of this document comes from a profile.
pub fn Document::is_derived(self : Document) -> Bool {
  self.written is None && self.derived is Some(_)
}

///|
/// The parsed Markdown body.
pub fn Document::markdown(self : Document) -> @mdc.Document? {
  self.markdown
}

///|
pub fn Document::is_concept(self : Document) -> Bool {
  self.kind is Concept
}

///|
/// The Concept ID, for a concept.
pub fn Document::concept_id(self : Document) -> ConceptId? {
  if self.kind is Concept {
    Some(ConceptId::of_path(self.path))
  } else {
    None
  }
}

///|
pub fn Document::concept_type(self : Document) -> String? {
  self.metadata().concept_type()
}

///|
/// `title`, else the file name without `.md`.
pub fn Document::display_title(self : Document) -> String {
  match self.metadata().title() {
    Some(title) => title
    None => {
      let name = self.path.name()
      if is_markdown_name(name) {
        name[:name.length() - 3].to_owned()
      } else {
        name
      }
    }
  }
}

///|
/// The file line for a line of the body as cmark counts it in the parsed text.
fn Document::file_line(self : Document, parsed_line : Int32) -> Int32 {
  // The parsed text has one extra blank line before the body.
  parsed_line - 1 + self.header.body_line - 1
}

///|
pub extend DocKind with Eq::{not_equal, equal}

///|
pub extend DocKind with @debug.Debug::{to_repr}
