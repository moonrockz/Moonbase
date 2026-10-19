///|
pub(all) suberror FormatError {
  InvalidJson(String)
  InvalidField(path~ : String, expected~ : String)
  UnsupportedVersion(major~ : Int32, minor~ : Int32)
  DuplicateCellId(String)
  DuplicateCellName(String)
} derive(Eq, Debug)

///|
pub extend FormatError with Eq::{equal, not_equal}

///|
pub extend FormatError with @debug.Debug::{to_repr}

///|
fn[X] invalid(path : String, expected : String) -> X raise FormatError {
  raise InvalidField(path~, expected~)
}

///|
fn copy_json(value : Json) -> Json {
  match value {
    Object(fields) => Json(fields.map((_, value) => copy_json(value)))
    Array(items) => Json(items.map(copy_json))
    Null | True | False | String(_) | Number(_) => value
  }
}

///|
/// An immutable JSON object. Both imports and exports copy the entire value
/// graph, including arrays and objects nested inside extension metadata.
struct JsonObject {
  fields : Map[String, Json]
} derive(Eq, Debug)

///|
pub extend JsonObject with Eq::{equal, not_equal}

///|
pub extend JsonObject with @debug.Debug::{to_repr}

///|
pub fn JsonObject::JsonObject(value : Json) -> JsonObject raise FormatError {
  object_at(value, "$")
}

///|
fn object_at(value : Json, path : String) -> JsonObject raise FormatError {
  guard copy_json(value) is Object(fields) else { invalid(path, "object") }
  { fields, }
}

///|
pub fn JsonObject::get(self : JsonObject, key : String) -> Json? {
  self.fields.get(key).map(copy_json)
}

///|
pub fn JsonObject::keys(self : JsonObject) -> ReadOnlyArray[String] {
  ReadOnlyArray::from_iter(self.fields.keys())
}

///|
pub fn JsonObject::to_json(self : JsonObject) -> Json {
  copy_json(Json(self.fields))
}

///|
fn field(
  object : JsonObject,
  key : String,
  path : String,
) -> Json raise FormatError {
  match object.fields.get(key) {
    Some(value) => value
    None => invalid(path + "." + key, "required field")
  }
}

///|
fn string_at(value : Json, path : String) -> String raise FormatError {
  guard value is String(text) else { invalid(path, "string") }
  text
}

///|
fn array_at(value : Json, path : String) -> Array[Json] raise FormatError {
  guard value is Array(items) else { invalid(path, "array") }
  items
}

///|
fn strings_at(
  value : Json,
  path : String,
) -> ReadOnlyArray[String] raise FormatError {
  let values = array_at(value, path)
  ReadOnlyArray::from_array(
    values.mapi((i, item) => string_at(item, "\{path}[\{i}]"))[:],
  )
}

///|
fn multiline(value : Json, path : String) -> String raise FormatError {
  match value {
    String(text) => text
    Array(_) => strings_at(value, path).join("")
    _ => invalid(path, "string or array of strings")
  }
}

///|
fn integer_at(value : Json, path : String) -> Int32 raise FormatError {
  guard value is Number(n, ..) && n >= 0 && n <= 2147483647.0 && n.floor() == n else {
    invalid(path, "nonnegative 32-bit integer")
  }
  n.to_int()
}

///|
/// MIME bundles join textual fragments and retain JSON MIME values as JSON.
struct MimeBundle {
  object : JsonObject
} derive(Eq, Debug)

///|
pub extend MimeBundle with Eq::{equal, not_equal}

///|
pub extend MimeBundle with @debug.Debug::{to_repr}

///|
pub fn MimeBundle::MimeBundle(value : Json) -> MimeBundle raise FormatError {
  mime_at(value, "$")
}

///|
fn mime_at(value : Json, path : String) -> MimeBundle raise FormatError {
  let object = object_at(value, path)
  let fields = Map([])
  for key, item in object.fields {
    fields[key] = if key == "application/json" || key.has_suffix("+json") {
      item
    } else {
      Json(multiline(item, path + "." + key))
    }
  }
  { object: { fields, }, }
}

///|
pub fn MimeBundle::get(self : MimeBundle, mime_type : String) -> Json? {
  self.object.get(mime_type)
}

///|
pub fn MimeBundle::mime_types(self : MimeBundle) -> ReadOnlyArray[String] {
  self.object.keys()
}

///|
pub fn MimeBundle::to_json(self : MimeBundle) -> Json {
  self.object.to_json()
}

///|
struct Attachments {
  entries : ReadOnlyArray[(String, MimeBundle)]
} derive(Eq, Debug)

///|
pub extend Attachments with Eq::{equal, not_equal}

///|
pub extend Attachments with @debug.Debug::{to_repr}

///|
pub fn Attachments::Attachments(value : Json) -> Attachments raise FormatError {
  attachments_at(value, "$")
}

///|
fn attachments_at(value : Json, path : String) -> Attachments raise FormatError {
  let object = object_at(value, path)
  let entries = []
  for name, bundle in object.fields {
    entries.push((name, mime_at(bundle, path + "." + name)))
  }
  entries.sort_by((left, right) => left.0[:].lexical_compare(right.0[:]))
  { entries: ReadOnlyArray::from_array(entries[:]), }
}

///|
pub fn Attachments::names(self : Attachments) -> ReadOnlyArray[String] {
  self.entries.map(entry => entry.0)
}

///|
pub fn Attachments::get(self : Attachments, name : String) -> MimeBundle? {
  for (key, bundle) in self.entries {
    if key == name {
      return Some(bundle)
    }
  }
  None
}

///|
pub fn Attachments::to_json(self : Attachments) -> Json {
  let fields = Map([])
  for (key, bundle) in self.entries {
    fields[key] = bundle.to_json()
  }
  Json(fields)
}
