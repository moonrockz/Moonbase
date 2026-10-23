///|
/// A document store over a directory of the local file system, for the
/// native and wasm targets. Every path must resolve inside the root, following
/// symlinks; a path that leaves it is refused with `PermissionDenied`.
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
fn FsStore::file(self : FsStore, path : @okf.StorePath) -> String {
  self.full(path.segments().iter().collect())
}

///|
fn failed(path : String, error : Error) -> @provider.StoreError {
  Failed(path, error.to_string())
}

///|
async fn exists(full : String) -> Bool raise @provider.StoreError {
  @fs.exists(full) catch {
    e => raise failed(full, e)
  }
}

///|
fn parent_of(path : String) -> String? {
  match path.rev_find("/") {
    Some(0) => Some("/")
    Some(i) => Some(path[:i].to_owned())
    None => None
  }
}

///|
/// The real path of the root.
async fn FsStore::real_root(
  self : FsStore,
) -> String raise @provider.StoreError {
  if !exists(self.root) {
    raise NotFound(self.root)
  }
  @fs.realpath(self.root) catch {
    e => raise failed(self.root, e)
  }
}

///|
fn is_inside(real : String, root : String) -> Bool {
  real == root ||
  real.has_prefix(if root.has_suffix("/") { root } else { root + "/" })
}

///|
/// Refuses `full` when it, or its nearest existing parent, resolves outside the
/// root after symlinks are followed.
async fn FsStore::confine(
  self : FsStore,
  full : String,
) -> Unit raise @provider.StoreError {
  let root = self.real_root()
  let mut current = full
  while true {
    if exists(current) {
      let real = @fs.realpath(current) catch { e => raise failed(current, e) }
      if !is_inside(real, root) {
        raise PermissionDenied(full)
      }
      return
    }
    match parent_of(current) {
      Some(parent) if parent != current => current = parent
      _ => return
    }
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn list(self, dir) {
  let full = self.full(dir)
  if !exists(full) {
    raise NotFound(full)
  }
  self.confine(full)
  let root = self.real_root()
  let names = @fs.readdir(full, include_hidden=false, sort=true) catch {
    e => raise failed(full, e)
  }
  let out = []
  for name in names {
    let child = full + "/" + name
    let kind = @fs.kind(child, follow_symlink=false) catch {
      e => raise failed(child, e)
    }
    let kind = match kind {
      SymLink => {
        // A symlink is listed only when it resolves inside the root.
        guard exists(child) else { continue }
        let real = @fs.realpath(child) catch { e => raise failed(child, e) }
        guard is_inside(real, root) else { continue }
        @fs.kind(child) catch {
          e => raise failed(child, e)
        }
      }
      other => other
    }
    match kind {
      Directory => out.push(@provider.StoreEntry::{ name, kind: Directory, })
      Regular => out.push(@provider.StoreEntry::{ name, kind: File, })
      _ => ()
    }
  }
  out.sort_by((a, b) => @okf.lexical_compare(a.name, b.name))
  out
}

///|
pub impl @provider.DocumentStore for FsStore with fn read_text(self, path) {
  let full = self.file(path)
  if !exists(full) {
    raise NotFound(full)
  }
  self.confine(full)
  let data = @fs.read_file(full) catch { e => raise failed(full, e) }
  data.text() catch {
    e => raise failed(full, e)
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn read_bytes(self, path) {
  let full = self.file(path)
  if !exists(full) {
    raise NotFound(full)
  }
  self.confine(full)
  let data = @fs.read_file(full) catch { e => raise failed(full, e) }
  data.binary()
}

///|
async fn FsStore::prepare_write(
  self : FsStore,
  path : @okf.StorePath,
) -> String raise @provider.StoreError {
  let full = self.file(path)
  let parent = path.parent()
  if !parent.is_empty() {
    let dir = self.full(parent)
    self.confine(dir)
    @fs.mkdir(dir, recursive=true, allow_exist=true) catch {
      e => raise failed(dir, e)
    }
  }
  self.confine(full)
  full
}

///|
pub impl @provider.DocumentStore for FsStore with fn write_text(
  self,
  path,
  text,
) {
  let full = self.prepare_write(path)
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
  let full = self.prepare_write(path)
  @fs.write_file(full, bytes, create_mode=CreateOrTruncate) catch {
    e => raise failed(full, e)
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn delete(self, path) {
  let full = self.file(path)
  // Deleting a symlink removes the link, so only its directory must be inside.
  match parent_of(full) {
    Some(parent) => self.confine(parent)
    None => ()
  }
  let present = exists(full) ||
    (@fs.kind(full, follow_symlink=false) catch { _ => Unknown }) is SymLink
  if present {
    @fs.remove(full) catch {
      e => raise failed(full, e)
    }
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn modified(self, path) {
  let full = self.file(path)
  if !exists(full) {
    raise NotFound(full)
  }
  self.confine(full)
  let (sec, nsec) = @fs.mtime(full) catch { e => raise failed(full, e) }
  Some(@okf.Instant::of_millis(sec * 1000L + (nsec / 1000000).to_int64()))
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
