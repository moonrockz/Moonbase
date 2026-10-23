///|
/// A frontmatter value. Every scalar is kept as text, so dates, timestamps and
/// numbers stay as written. Typed accessors read the text when asked.
pub(all) enum Value {
  Scalar(String)
  Seq(ReadOnlyArray[Value])
  Mapping(Fields)
  Null
} derive(Eq, Debug)

///|
/// An ordered set of keys and values. Keys keep their source order.
struct Fields {
  entries : ReadOnlyArray[(String, Value)]
} derive(Eq, Debug)

///|
/// Builds fields from ordered pairs. A later pair for the same key replaces
/// the value of the earlier pair and keeps its position.
pub fn Fields::Fields(pairs : ArrayView[(String, Value)]) -> Fields {
  let out : Array[(String, Value)] = []
  for pair in pairs {
    match out.search_by(p => p.0 == pair.0) {
      Some(i) => out[i] = pair
      None => out.push(pair)
    }
  }
  { entries: ReadOnlyArray::from_array(out), }
}

///|
pub fn Fields::entries(self : Fields) -> ReadOnlyArray[(String, Value)] {
  self.entries
}

///|
pub fn Fields::keys(self : Fields) -> Array[String] {
  self.entries.iter().map(e => e.0).collect()
}

///|
pub fn Fields::get(self : Fields, key : String) -> Value? {
  for entry in self.entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
/// The text of a scalar value, or `None` for other values.
pub fn Value::as_text(self : Value) -> String? {
  match self {
    Scalar(text) => Some(text)
    _ => None
  }
}

///|
/// Reads a value as a list of texts. A scalar becomes a list with one item.
/// Items that are not scalars are left out.
pub fn Value::as_texts(self : Value) -> Array[String] {
  match self {
    Scalar(text) => [text]
    Seq(items) => items.iter().filter_map(v => v.as_text()).collect()
    _ => []
  }
}

///|
/// Reads a value as a list of mappings. A mapping becomes a list with one item.
pub fn Value::as_mappings(self : Value) -> Array[Fields] {
  match self {
    Mapping(fields) => [fields]
    Seq(items) =>
      items
      .iter()
      .filter_map(v => {
        match v {
          Mapping(fields) => Some(fields)
          _ => None
        }
      })
      .collect()
    _ => []
  }
}

///|
/// Reads `true`, `yes` and `on` as true and `false`, `no` and `off` as false,
/// ignoring letter case.
pub fn Value::as_bool(self : Value) -> Bool? {
  match self {
    Scalar(text) =>
      match text.to_lower() {
        "true" | "yes" | "on" => Some(true)
        "false" | "no" | "off" => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
pub fn Value::as_int(self : Value) -> Int32? {
  match self {
    Scalar(text) => parse_int_text(text)
    _ => None
  }
}

///|
fn parse_int_text(text : String) -> Int32? {
  let text = text.trim(chars=" \t").to_owned()
  if text.length() == 0 {
    return None
  }
  let mut i = 0
  let negative = text[0] == '-'
  if text[0] == '-' || text[0] == '+' {
    i = 1
  }
  if i >= text.length() {
    return None
  }
  let mut value = 0
  while i < text.length() {
    let c = text[i]
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i += 1
  }
  Some(if negative { -value } else { value })
}

///|
/// Converts a YAML value into a frontmatter value.
fn value_of_yaml(yaml : @yaml.Yaml) -> Value {
  match yaml {
    Real(_, repr~) => Scalar(repr)
    Integer(n) => Scalar(n.to_string())
    String(s) => Scalar(s)
    Boolean(b) => Scalar(b.to_string())
    Array(items) => Seq(ReadOnlyArray::from_array(items.map(value_of_yaml)))
    Map(map) => {
      let pairs = []
      for key, value in map {
        pairs.push((key, value_of_yaml(value)))
      }
      Mapping(Fields(pairs))
    }
    Null | BadValue => Null
  }
}

///|
/// The parsed frontmatter of a document: the raw block, its ordered fields and
/// the location of each top-level key.
struct Metadata {
  raw : String
  fields : Fields
  entries : ReadOnlyArray[RawEntry]
  /// The file line of the first line of the raw block.
  first_line : Int32
} derive(Eq, Debug)

///|
/// Raised when a frontmatter block cannot be read.
pub(all) suberror MetadataError {
  /// The YAML is invalid, or not a mapping. The line and column are file positions.
  InvalidYaml(line~ : Int32, column~ : Int32, message~ : String)
  /// The block has no closing delimiter line.
  Unterminated
} derive(Eq, Debug)

///|
/// Parses a raw frontmatter block. `first_line` is the file line of the first
/// line of `raw`; error positions are file positions.
pub fn Metadata::Metadata(
  raw : String,
  first_line~ : Int32 = 2,
) -> Metadata raise MetadataError {
  let frontmatter = @mdc.Frontmatter::Frontmatter(raw) catch {
    InvalidFrontmatter(line~, column~, message~) =>
      raise InvalidYaml(line=line + first_line - 1, column~, message~)
    UnterminatedFrontmatter => raise Unterminated
  }
  let entries = scan_entries(raw)
  let pairs = []
  match frontmatter.value() {
    Map(map) =>
      for key, value in map {
        let value = match value {
          Integer(_) | Real(_, ..) | Boolean(_) =>
            match entries.search_by(e => e.key == key) {
              Some(i) if entries[i].inline.length() > 0 =>
                Scalar(entries[i].inline)
              _ => value_of_yaml(value)
            }
          _ => value_of_yaml(value)
        }
        pairs.push((key, value))
      }
    _ => ()
  }
  {
    raw,
    fields: Fields(pairs),
    entries: ReadOnlyArray::from_array(entries),
    first_line,
  }
}

///|
/// An empty frontmatter, as in an empty block.
pub fn Metadata::empty() -> Metadata {
  {
    raw: "",
    fields: Fields([]),
    entries: ReadOnlyArray::from_array([]),
    first_line: 2,
  }
}

///|
/// Metadata from fields, for derived metadata that has no source text.
pub fn Metadata::of_fields(fields : Fields) -> Metadata {
  { raw: "", fields, entries: ReadOnlyArray::from_array([]), first_line: 0, }
}

///|
pub fn Metadata::raw(self : Metadata) -> String {
  self.raw
}

///|
pub fn Metadata::fields(self : Metadata) -> Fields {
  self.fields
}

///|
/// The top-level keys in source order.
pub fn Metadata::keys(self : Metadata) -> Array[String] {
  self.fields.keys()
}

///|
pub fn Metadata::get(self : Metadata, key : String) -> Value? {
  self.fields.get(key)
}

///|
pub fn Metadata::contains(self : Metadata, key : String) -> Bool {
  self.fields.get(key) is Some(_)
}

///|
/// The text of a scalar key. An empty or missing value gives `None`.
pub fn Metadata::text(self : Metadata, key : String) -> String? {
  match self.fields.get(key) {
    Some(Scalar(text)) if text.length() > 0 => Some(text)
    _ => None
  }
}

///|
/// A key read as a list of texts; a scalar gives a list with one item.
pub fn Metadata::texts(self : Metadata, key : String) -> Array[String] {
  match self.fields.get(key) {
    Some(value) => value.as_texts()
    None => []
  }
}

///|
pub fn Metadata::bool(self : Metadata, key : String) -> Bool? {
  match self.fields.get(key) {
    Some(value) => value.as_bool()
    None => None
  }
}

///|
pub fn Metadata::int(self : Metadata, key : String) -> Int32? {
  match self.fields.get(key) {
    Some(value) => value.as_int()
    None => None
  }
}

///|
/// A key read as a list of mappings; a mapping gives a list with one item.
pub fn Metadata::mappings(self : Metadata, key : String) -> Array[Fields] {
  match self.fields.get(key) {
    Some(value) => value.as_mappings()
    None => []
  }
}

///|
/// The raw source text after `key:` on its line, as written.
pub fn Metadata::raw_text(self : Metadata, key : String) -> String? {
  for entry in self.entries {
    if entry.key == key {
      return Some(entry.inline)
    }
  }
  None
}

///|
/// The file line of a top-level key, when the metadata has source text.
pub fn Metadata::line_of(self : Metadata, key : String) -> Int32? {
  for entry in self.entries {
    if entry.key == key {
      return Some(self.first_line + entry.first_line)
    }
  }
  None
}

///|
/// The located top-level keys.
pub fn Metadata::raw_entries(self : Metadata) -> ReadOnlyArray[RawEntry] {
  self.entries
}

///|
/// A text field of a mapping.
pub fn Fields::text(self : Fields, key : String) -> String? {
  match self.get(key) {
    Some(Scalar(text)) if text.length() > 0 => Some(text)
    _ => None
  }
}

///|
pub fn Fields::texts(self : Fields, key : String) -> Array[String] {
  match self.get(key) {
    Some(value) => value.as_texts()
    None => []
  }
}

///|
pub fn Fields::bool(self : Fields, key : String) -> Bool? {
  match self.get(key) {
    Some(value) => value.as_bool()
    None => None
  }
}

///|
pub fn Fields::int(self : Fields, key : String) -> Int32? {
  match self.get(key) {
    Some(value) => value.as_int()
    None => None
  }
}

///|
pub extend Value with Eq::{not_equal, equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
pub extend Fields with Eq::{not_equal, equal}

///|
pub extend Fields with @debug.Debug::{to_repr}

///|
pub extend Metadata with Eq::{not_equal, equal}

///|
pub extend Metadata with @debug.Debug::{to_repr}

///|
pub extend MetadataError with Eq::{not_equal, equal}

///|
pub extend MetadataError with @debug.Debug::{to_repr}
