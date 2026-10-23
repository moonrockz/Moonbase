///|
/// Reads every file under `dir` (relative to the tests module) into a document
/// set, with paths relative to `dir`.
fn load_fixture(dir : String) -> @okf.DocumentSet raise {
  let entries = []
  fn walk(rel : String) raise {
    let full = if rel == "" { dir } else { dir + "/" + rel }
    let names = @fs.read_dir(full).to_owned()
    names.sort()
    for name in names {
      let child = if rel == "" { name } else { rel + "/" + name }
      let path = dir + "/" + child
      if @fs.is_dir(path) {
        walk(child)
      } else {
        entries.push(@okf.FileEntry::{
          path: @okf.StorePath(child),
          content: @okf.FileContent::Text(@fs.read_file_to_string(path)),
        })
      }
    }
  }
  walk("")
  @okf.DocumentSet(entries)
}

///|
fn read_golden(name : String) -> Json raise {
  @json.parse(@fs.read_file_to_string("okf-fixtures/morphir/golden/" + name))
}

///|
fn morphir_knowledge() -> @okf.Knowledge raise {
  @okf.discover(load_fixture("okf-fixtures/morphir/kb"), under=["bundles"])
}
