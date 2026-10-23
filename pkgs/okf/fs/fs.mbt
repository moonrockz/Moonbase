///|
/// A document store over a directory of the local file system, for the
/// native and wasm targets.
struct FsStore {
  root : String
}

///|
/// A store rooted at the directory `root`.
pub fn FsStore::FsStore(root : String) -> FsStore {
  let root = if root.length() > 1 && root.has_suffix("/") {
    root[:root.length() - 1].to_owned()
  } else {
    root
  }
  { root, }
}

///|
pub fn FsStore::root(self : FsStore) -> String {
  self.root
}

///|
fn FsStore::full(self : FsStore, segments : ArrayView[String]) -> String {
  if segments.is_empty() {
    self.root
  } else {
    self.root + "/" + segments.iter().collect().join("/")
  }
}

///|
fn failed(path : String, error : Error) -> @provider.StoreError {
  Failed(path, error.to_string())
}

///|
pub impl @provider.DocumentStore for FsStore with fn list(self, dir) {
  let full = self.full(dir)
  if !exists(full) {
    raise NotFound(full)
  }
  let names = @fs.readdir(full, include_hidden=false, sort=true) catch {
    e => raise failed(full, e)
  }
  let out = []
  for name in names {
    let kind = @fs.kind(full + "/" + name) catch {
      e => raise failed(full + "/" + name, e)
    }
    match kind {
      Directory => out.push(@provider.StoreEntry::{ name, kind: Directory, })
      Regular | SymLink => out.push(@provider.StoreEntry::{ name, kind: File, })
      _ => ()
    }
  }
  out.sort_by((a, b) => @okf.lexical_compare(a.name, b.name))
  out
}

///|
pub impl @provider.DocumentStore for FsStore with fn read_text(self, path) {
  let full = self.full(path.segments().iter().collect())
  if !exists(full) {
    raise NotFound(full)
  }
  let data = @fs.read_file(full) catch { e => raise failed(full, e) }
  data.text() catch {
    e => raise failed(full, e)
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn read_bytes(self, path) {
  let full = self.full(path.segments().iter().collect())
  if !exists(full) {
    raise NotFound(full)
  }
  let data = @fs.read_file(full) catch { e => raise failed(full, e) }
  data.binary()
}

///|
async fn FsStore::ensure_parent(
  self : FsStore,
  path : @okf.StorePath,
) -> Unit raise @provider.StoreError {
  let parent = path.parent()
  if !parent.is_empty() {
    let dir = self.full(parent)
    @fs.mkdir(dir, recursive=true, allow_exist=true) catch {
      e => raise failed(dir, e)
    }
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn write_text(
  self,
  path,
  text,
) {
  self.ensure_parent(path)
  let full = self.full(path.segments().iter().collect())
  @fs.write_file(full, text, create_mode=CreateOrTruncate) catch {
    e => raise failed(full, e)
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn write_bytes(
  self,
  path,
  bytes,
) {
  self.ensure_parent(path)
  let full = self.full(path.segments().iter().collect())
  @fs.write_file(full, bytes, create_mode=CreateOrTruncate) catch {
    e => raise failed(full, e)
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn delete(self, path) {
  let full = self.full(path.segments().iter().collect())
  if exists(full) {
    @fs.remove(full) catch {
      e => raise failed(full, e)
    }
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn modified(self, path) {
  let full = self.full(path.segments().iter().collect())
  if !exists(full) {
    raise NotFound(full)
  }
  let (sec, nsec) = @fs.mtime(full) catch { e => raise failed(full, e) }
  Some(@okf.Instant::of_millis(sec * 1000L + (nsec / 1000000).to_int64()))
}

///|
async fn exists(full : String) -> Bool raise @provider.StoreError {
  @fs.exists(full) catch {
    e => raise failed(full, e)
  }
}

///|
pub extend FsStore with @provider.DocumentStore::{
  read_bytes,
  list,
  write_bytes,
  delete,
  modified,
  read_text,
  write_text,
}
