///|
pub(all) suberror FormatError {
  InvalidMetadata(line~ : Int32, message~ : String)
  InvalidKernelName(String)
  DuplicateKernelName(String)
  UnknownKernel(String)
  UnrepresentableSource(cell~ : Int32, line~ : Int32)
} derive(Eq, Debug)

///|
pub extend FormatError with Eq::{equal, not_equal}

///|
pub extend FormatError with @debug.Debug::{to_repr}

///|
struct KernelName {
  value : String
} derive(Eq, Debug)

///|
pub extend KernelName with Eq::{equal, not_equal}

///|
pub extend KernelName with @debug.Debug::{to_repr}

///|
pub fn KernelName::KernelName(value : String) -> KernelName raise FormatError {
  if value.trim().is_empty() ||
    value.has_prefix("#") ||
    value == "meta" ||
    value.contains("\n") ||
    value.contains("\r") {
    raise InvalidKernelName(value)
  }
  { value, }
}

///|
pub fn KernelName::to_string(self : KernelName) -> String {
  self.value
}

///|
struct KernelInfo {
  name : KernelName
  aliases : ReadOnlyArray[KernelName]
  language : String?
} derive(Eq, Debug)

///|
pub extend KernelInfo with Eq::{equal, not_equal}

///|
pub extend KernelInfo with @debug.Debug::{to_repr}

///|
pub fn KernelInfo::KernelInfo(
  name : KernelName,
  aliases~ : ReadOnlyArray[KernelName] = [],
  language~ : String? = None,
) -> KernelInfo {
  { name, aliases, language, }
}

///|
pub fn KernelInfo::name(self : KernelInfo) -> KernelName {
  self.name
}

///|
pub fn KernelInfo::aliases(self : KernelInfo) -> ReadOnlyArray[KernelName] {
  self.aliases
}

///|
pub fn KernelInfo::language(self : KernelInfo) -> String? {
  self.language
}

///|
/// The registry distinguishes cell selectors from executable directives.
struct KernelRegistry {
  kernels : ReadOnlyArray[KernelInfo]
  default_kernel : KernelName
  aliases : Map[String, KernelName]
} derive(Eq, Debug)

///|
pub extend KernelRegistry with Eq::{equal, not_equal}

///|
pub extend KernelRegistry with @debug.Debug::{to_repr}

///|
pub fn KernelRegistry::KernelRegistry(
  kernels : ReadOnlyArray[KernelInfo],
  default_kernel~ : KernelName,
) -> KernelRegistry raise FormatError {
  let aliases = Map([])
  for kernel in kernels {
    for alternate in kernel.aliases.iter().concat([kernel.name].iter()) {
      if aliases.contains(alternate.value) {
        raise DuplicateKernelName(alternate.value)
      }
      aliases[alternate.value] = kernel.name
    }
  }
  guard aliases.get(default_kernel.value) is Some(default_kernel) else {
    raise UnknownKernel(default_kernel.value)
  }
  { kernels, default_kernel, aliases, }
}

///|
pub fn KernelRegistry::kernels(
  self : KernelRegistry,
) -> ReadOnlyArray[KernelInfo] {
  self.kernels
}

///|
pub fn KernelRegistry::default_kernel(self : KernelRegistry) -> KernelName {
  self.default_kernel
}

///|
pub fn KernelRegistry::resolve(
  self : KernelRegistry,
  name : String,
) -> KernelName? {
  self.aliases.get(name)
}

///|
/// Standard Polyglot kernel names. Custom environments supply a registry.
pub fn KernelRegistry::standard() -> KernelRegistry {
  let descriptions : Array[(String, Array[String])] = [
    ("csharp", ["cs", "C#", "c#"]),
    ("fsharp", ["fs", "F#", "f#"]),
    ("pwsh", ["powershell"]),
    ("javascript", ["js"]),
    ("html", []),
    ("sql", []),
    ("kql", []),
    ("http", []),
    ("value", []),
    ("mermaid", []),
  ]
  let kernels = []
  let aliases = Map([])
  for (name, names) in descriptions {
    let name = KernelName::{ value: name, }
    aliases[name.value] = name
    for alternate in names {
      aliases[alternate] = name
    }
    kernels.push(KernelInfo::{
      name,
      aliases: ReadOnlyArray::from_iter(
        names.iter().map(value => KernelName::{ value, }),
      ),
      language: None,
    })
  }
  {
    kernels: ReadOnlyArray::from_array(kernels[:]),
    default_kernel: { value: "csharp", },
    aliases,
  }
}

///|
fn copy_json(value : Json) -> Json {
  match value {
    Object(fields) => Json(fields.map((_, value) => copy_json(value)))
    Array(items) => Json(items.map(copy_json))
    _ => value
  }
}

///|
struct Metadata {
  value : Json
} derive(Eq, Debug)

///|
pub extend Metadata with Eq::{equal, not_equal}

///|
pub extend Metadata with @debug.Debug::{to_repr}

///|
pub fn Metadata::Metadata(value : Json) -> Metadata raise FormatError {
  guard value is Object(_) else {
    raise InvalidMetadata(line=1, message="expected an object")
  }
  { value: copy_json(value), }
}

///|
pub fn Metadata::get(self : Metadata, name : String) -> Json? {
  match self.value {
    Object(fields) => fields.get(name).map(copy_json)
    _ => None
  }
}

///|
pub fn Metadata::to_json(self : Metadata) -> Json {
  copy_json(self.value)
}

///|
struct Cell {
  source : String
  kernel : KernelName
} derive(Eq, Debug)

///|
pub extend Cell with Eq::{equal, not_equal}

///|
pub extend Cell with @debug.Debug::{to_repr}

///|
pub fn Cell::Cell(source : String, kernel~ : KernelName) -> Cell {
  { source: normalize_source(source), kernel, }
}

///|
pub fn Cell::source(self : Cell) -> String {
  self.source
}

///|
pub fn Cell::kernel(self : Cell) -> KernelName {
  self.kernel
}

///|
pub fn Cell::kind(self : Cell) -> @notebooks.CellKind {
  if self.kernel.value == "markdown" || self.kernel.value == "md" {
    @notebooks.Markdown
  } else {
    @notebooks.Code
  }
}

///|
struct Directive {
  text : String
  name : String
  arguments : String
  line : Int32
} derive(Eq, Debug)

///|
pub extend Directive with Eq::{equal, not_equal}

///|
pub extend Directive with @debug.Debug::{to_repr}

///|
pub fn Directive::text(self : Directive) -> String {
  self.text
}

///|
pub fn Directive::name(self : Directive) -> String {
  self.name
}

///|
pub fn Directive::arguments(self : Directive) -> String {
  self.arguments
}

///|
/// One-based line relative to the normalized cell source.
pub fn Directive::line(self : Directive) -> Int32 {
  self.line
}

///|
pub fn Cell::directives(self : Cell) -> ReadOnlyArray[Directive] {
  let directives = []
  for i, text in self.source.split("\n").to_array() {
    if text.has_prefix("#!") {
      let rest = text[2:]
      let mut end = 0
      while end < rest.length() &&
            rest.code_unit_at(end) != 32 &&
            rest.code_unit_at(end) != 9 {
        end += 1
      }
      directives.push({
        text: text.to_owned(),
        name: rest[:end].to_owned(),
        arguments: rest[end:].trim_start().to_owned(),
        line: i + 1,
      })
    }
  }
  ReadOnlyArray::from_array(directives[:])
}

///|
struct Notebook {
  cells : ReadOnlyArray[Cell]
  metadata : Metadata
  registry : KernelRegistry
} derive(Eq, Debug)

///|
pub extend Notebook with Eq::{equal, not_equal}

///|
pub extend Notebook with @debug.Debug::{to_repr}

///|
pub fn Notebook::Notebook(
  cells : ReadOnlyArray[Cell],
  metadata~ : Metadata = { value: {}, },
  registry~ : KernelRegistry = KernelRegistry::standard(),
) -> Notebook raise FormatError {
  let registry = registry_from_metadata(metadata, registry)
  let cells = cells.map(cell => {
    guard registry.resolve(cell.kernel.value) is Some(kernel) else {
      raise UnknownKernel(cell.kernel.value)
    }
    Cell::{ source: cell.source, kernel, }
  })
  { cells, metadata, registry, }
}

///|
pub fn Notebook::cells(self : Notebook) -> ReadOnlyArray[Cell] {
  self.cells
}

///|
pub fn Notebook::cell(self : Notebook, index : Int32) -> Cell? {
  self.cells.get(index)
}

///|
pub fn Notebook::metadata(self : Notebook) -> Metadata {
  self.metadata
}

///|
pub fn Notebook::registry(self : Notebook) -> KernelRegistry {
  self.registry
}
