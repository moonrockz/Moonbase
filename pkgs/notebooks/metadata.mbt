///|
/// A failure to construct metadata from a non-object JSON value.
pub(all) suberror MetadataError {
  /// Metadata must be a JSON object, including when empty.
  ExpectedObject
} derive(Eq, Debug)

///|
pub extend MetadataError with Eq::{equal, not_equal}

///|
pub extend MetadataError with @debug.Debug::{to_repr}

///|
/// Immutable attributes belonging to one notebook node. Construction and
/// exports deep-copy JSON so nested mutable values cannot change metadata.
/// Format-specific constructors validate the meaning of reserved keys.
struct Metadata {
  fields : Map[String, Json]
} derive(Eq, Debug)

///|
pub extend Metadata with Eq::{equal, not_equal}

///|
pub extend Metadata with @debug.Debug::{to_repr}

///|
fn copy_metadata_json(value : Json) -> Json {
  match value {
    Object(fields) => Json(fields.map((_, value) => copy_metadata_json(value)))
    Array(items) => Json(items.map(copy_metadata_json))
    _ => value
  }
}

///|
/// Require a JSON object and copy its entire value graph. Raise ExpectedObject
/// for any other JSON type. Custom keys and JSON values are retained.
pub fn Metadata::Metadata(value : Json) -> Metadata raise MetadataError {
  guard copy_metadata_json(value) is Object(fields) else {
    raise ExpectedObject
  }
  { fields, }
}

///|
/// Create an empty metadata container without a fallible JSON conversion.
pub fn Metadata::empty() -> Metadata {
  { fields: {}, }
}

///|
/// Look up an exact key, returning an independent JSON value or None.
/// A present JSON null is Some(Null), distinct from an absent key.
pub fn Metadata::get(self : Metadata, key : String) -> Json? {
  self.fields.get(key).map(copy_metadata_json)
}

///|
/// Return immutable keys without a sorting guarantee.
pub fn Metadata::keys(self : Metadata) -> ReadOnlyArray[String] {
  ReadOnlyArray::from_iter(self.fields.keys())
}

///|
/// Return whether this available metadata container has no attributes.
pub fn Metadata::is_empty(self : Metadata) -> Bool {
  self.fields.is_empty()
}

///|
/// Export an independent JSON object that callers may mutate safely.
pub fn Metadata::to_json(self : Metadata) -> Json {
  copy_metadata_json(Json(self.fields))
}
