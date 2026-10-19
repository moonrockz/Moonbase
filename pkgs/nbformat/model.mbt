///|
struct CellId {
  value : String
} derive(Eq, Debug)

///|
pub extend CellId with Eq::{equal, not_equal}

///|
pub extend CellId with @debug.Debug::{to_repr}

///|
pub fn CellId::CellId(value : String) -> CellId raise FormatError {
  cell_id_at(Json(value), "$.id")
}

///|
fn cell_id_at(value : Json, path : String) -> CellId raise FormatError {
  let value = string_at(value, path)
  guard value.length() >= 1 && value.length() <= 64 else {
    invalid(path, "cell ID of 1 to 64 ASCII letters, digits, '-' or '_'")
  }
  for unit in value.code_units() {
    guard (unit >= 65 && unit <= 90) ||
      (unit >= 97 && unit <= 122) ||
      (unit >= 48 && unit <= 57) ||
      unit == 45 ||
      unit == 95 else {
      invalid(path, "cell ID of 1 to 64 ASCII letters, digits, '-' or '_'")
    }
  }
  { value, }
}

///|
pub fn CellId::to_string(self : CellId) -> String {
  self.value
}

///|
/// A nonnegative integral JSON number. Preserve the JSON representation to
/// avoid rounding large execution counts through a machine integer.
struct ExecutionCount {
  value : Json
} derive(Eq, Debug)

///|
pub extend ExecutionCount with Eq::{equal, not_equal}

///|
pub extend ExecutionCount with @debug.Debug::{to_repr}

///|
pub fn ExecutionCount::ExecutionCount(
  value : Int32,
) -> ExecutionCount raise FormatError {
  count_at(Json(value), "$.execution_count")
}

///|
pub fn ExecutionCount::from_json(
  value : Json,
) -> ExecutionCount raise FormatError {
  count_at(value, "$.execution_count")
}

///|
fn count_at(value : Json, path : String) -> ExecutionCount raise FormatError {
  guard value is Number(n, ..) &&
    n >= 0 &&
    n < @double.infinity &&
    n.floor() == n else {
    invalid(path, "nonnegative integer")
  }
  { value, }
}

///|
pub fn ExecutionCount::to_json(self : ExecutionCount) -> Json {
  self.value
}

///|
/// None represents an unexecuted cell or an output with a null count.
pub(all) enum OutputContent {
  Stream(name~ : String, text~ : String)
  DisplayData(data~ : MimeBundle, metadata~ : JsonObject)
  ExecuteResult(
    data~ : MimeBundle,
    metadata~ : JsonObject,
    execution_count~ : ExecutionCount?
  )
  Error(ename~ : String, evalue~ : String, traceback~ : ReadOnlyArray[String])
  Unknown(output_type~ : String, fields~ : JsonObject)
} derive(Eq, Debug)

///|
pub extend OutputContent with Eq::{equal, not_equal}

///|
pub extend OutputContent with @debug.Debug::{to_repr}

///|
struct Output {
  content : OutputContent
  extensions : JsonObject
} derive(Eq, Debug)

///|
pub extend Output with Eq::{equal, not_equal}

///|
pub extend Output with @debug.Debug::{to_repr}

///|
pub fn Output::Output(content : OutputContent) -> Output raise FormatError {
  if content is Unknown(output_type~, fields~) {
    if ["stream", "display_data", "execute_result", "error"].contains(
        output_type,
      ) {
      invalid("$.output_type", "unrecognized output type for Unknown")
    }
    if fields.fields.contains("output_type") {
      invalid("$.output_type", "output_type supplied separately")
    }
  }
  let output = Output::{ content, extensions: { fields: {}, }, }
  // Use the codec boundary for the same validation as imported notebooks.
  output_at(output.to_json(), "$")
}

///|
pub fn Output::content(self : Output) -> OutputContent {
  self.content
}

///|
pub fn Output::extensions(self : Output) -> JsonObject {
  self.extensions
}

///|
pub fn Output::output_type(self : Output) -> String {
  match self.content {
    Stream(_) => "stream"
    DisplayData(_) => "display_data"
    ExecuteResult(_) => "execute_result"
    Error(_) => "error"
    Unknown(output_type~, ..) => output_type
  }
}

///|
pub(all) enum CellContent {
  Markdown(source~ : String, attachments~ : Attachments?)
  Raw(source~ : String, attachments~ : Attachments?)
  Code(
    source~ : String,
    execution_count~ : ExecutionCount?,
    outputs~ : ReadOnlyArray[Output]
  )
  Unknown(cell_type~ : String, fields~ : JsonObject)
} derive(Eq, Debug)

///|
pub extend CellContent with Eq::{equal, not_equal}

///|
pub extend CellContent with @debug.Debug::{to_repr}

///|
struct Cell {
  id : CellId?
  metadata : JsonObject
  content : CellContent
  extensions : JsonObject
} derive(Eq, Debug)

///|
pub extend Cell with Eq::{equal, not_equal}

///|
pub extend Cell with @debug.Debug::{to_repr}

///|
pub fn Cell::Cell(
  content : CellContent,
  id~ : CellId? = None,
  metadata~ : JsonObject = { fields: {}, },
) -> Cell raise FormatError {
  if content is Unknown(cell_type~, fields~) {
    if ["markdown", "raw", "code"].contains(cell_type) {
      invalid("$.cell_type", "unrecognized cell type for Unknown")
    }
    for key in ["cell_type", "id", "metadata"] {
      if fields.fields.contains(key) {
        invalid("$." + key, "common cell field supplied separately")
      }
    }
  }
  let cell = Cell::{ id, metadata, content, extensions: { fields: {}, }, }
  cell_at(cell.to_json(), "$", 0)
}

///|
pub fn Cell::id(self : Cell) -> CellId? {
  self.id
}

///|
pub fn Cell::metadata(self : Cell) -> JsonObject {
  self.metadata
}

///|
pub fn Cell::content(self : Cell) -> CellContent {
  self.content
}

///|
pub fn Cell::extensions(self : Cell) -> JsonObject {
  self.extensions
}

///|
pub fn Cell::cell_type(self : Cell) -> String {
  match self.content {
    Markdown(_) => "markdown"
    Raw(_) => "raw"
    Code(_) => "code"
    Unknown(cell_type~, ..) => cell_type
  }
}

///|
pub fn Cell::source(self : Cell) -> String? {
  match self.content {
    Markdown(source~, ..) | Raw(source~, ..) | Code(source~, ..) => Some(source)
    Unknown(_) => None
  }
}

///|
pub fn Cell::outputs(self : Cell) -> ReadOnlyArray[Output] {
  match self.content {
    Code(outputs~, ..) => outputs
    _ => []
  }
}

///|
struct Notebook {
  minor : Int32
  metadata : JsonObject
  cells : ReadOnlyArray[Cell]
  extensions : JsonObject
} derive(Eq, Debug)

///|
pub extend Notebook with Eq::{equal, not_equal}

///|
pub extend Notebook with @debug.Debug::{to_repr}

///|
/// Construct a v4 notebook. v4.5 and later require unique cell IDs.
pub fn Notebook::Notebook(
  cells : ReadOnlyArray[Cell],
  minor~ : Int32 = 5,
  metadata~ : JsonObject = { fields: {}, },
) -> Notebook raise FormatError {
  if minor < 0 {
    raise UnsupportedVersion(major=4, minor~)
  }
  validate_notebook_metadata(metadata, "$.metadata")
  validate_cells(cells, minor)
  { minor, metadata, cells, extensions: { fields: {}, }, }
}

///|
pub fn Notebook::nbformat(_self : Notebook) -> Int32 {
  4
}

///|
pub fn Notebook::nbformat_minor(self : Notebook) -> Int32 {
  self.minor
}

///|
pub fn Notebook::metadata(self : Notebook) -> JsonObject {
  self.metadata
}

///|
pub fn Notebook::cells(self : Notebook) -> ReadOnlyArray[Cell] {
  self.cells
}

///|
pub fn Notebook::extensions(self : Notebook) -> JsonObject {
  self.extensions
}

///|
pub fn Notebook::cell(self : Notebook, index : Int32) -> Cell? {
  self.cells.get(index)
}

///|
pub fn Notebook::cell_by_id(self : Notebook, id : CellId) -> Cell? {
  for cell in self.cells {
    if cell.id == Some(id) {
      return Some(cell)
    }
  }
  None
}
