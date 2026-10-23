///|
/// Whether a store entry is a file or a directory.
pub(all) enum EntryKind {
  File
  Directory
} derive(Eq, Debug)

///|
/// One entry of a directory listing.
pub(all) struct StoreEntry {
  name : String
  kind : EntryKind
} derive(Eq, Debug)

///|
/// Raised by a document store.
pub(all) suberror StoreError {
  /// The path does not exist.
  NotFound(String)
  /// The store does not allow the operation on the path.
  PermissionDenied(String)
  /// The path is not valid for the store, for example because it escapes the root.
  InvalidPath(String)
  /// Any other failure, with the path and a message.
  Failed(String, String)
} derive(Eq, Debug)

///|
/// Reads and writes documents. Paths are relative to the root of the store and
/// never escape it. Implementations must list entries in a stable order.
pub(open) trait DocumentStore {
  /// The entries of a directory, given as segments (`[]` for the root).
  async fn list(Self, ArrayView[String]) -> Array[StoreEntry] raise StoreError
  async fn read_text(Self, @okf.StorePath) -> String raise StoreError
  async fn read_bytes(Self, @okf.StorePath) -> Bytes raise StoreError
  /// Writes text, and creates missing parent directories.
  async fn write_text(Self, @okf.StorePath, String) -> Unit raise StoreError
  /// Writes bytes, and creates missing parent directories.
  async fn write_bytes(Self, @okf.StorePath, Bytes) -> Unit raise StoreError
  /// Deletes a file. Deleting a missing file is not an error.
  async fn delete(Self, @okf.StorePath) -> Unit raise StoreError
  /// The modification time of a file, when the store knows it.
  async fn modified(Self, @okf.StorePath) -> @okf.Instant? raise StoreError
}

///|
/// Validates a path for a store: `/` and `\` are both separators, and a path
/// that escapes the root is refused.
pub fn safe_path(text : String) -> @okf.StorePath raise StoreError {
  @okf.StorePath(text) catch {
    _ => raise InvalidPath(text)
  }
}

///|
/// Reads every file under `under` into a document set. Markdown files are read
/// as text and other files as bytes; `assets=false` leaves other files out.
pub async fn load_set(
  store : &DocumentStore,
  under~ : ArrayView[String] = [],
  assets~ : Bool = true,
) -> @okf.DocumentSet raise StoreError {
  let entries : Array[@okf.FileEntry] = []
  async fn walk(dir : Array[String]) -> Unit raise StoreError {
    for entry in store.list(dir) {
      let child = dir.copy()
      child.push(entry.name)
      match entry.kind {
        Directory => walk(child)
        File => {
          let path = safe_path(child.join("/"))
          if @okf.is_markdown_name(entry.name) {
            entries.push({ path, content: Text(store.read_text(path)), })
          } else if assets {
            entries.push({ path, content: Bytes(store.read_bytes(path)), })
          }
        }
      }
    }
  }
  walk(under.to_owned())
  @okf.DocumentSet(entries)
}

///|
/// Discovers the bundles under `under` in a store.
pub async fn load(
  store : &DocumentStore,
  under~ : ArrayView[String] = [],
  options~ : @okf.Options = @okf.Options::default(),
  profiles~ : ArrayView[&@okf.Profile] = [],
) -> @okf.Knowledge raise StoreError {
  let set = load_set(store, under~)
  @okf.discover(set, under~, options~, profiles~)
}

///|
/// Loads the bundle at `root` in a store.
pub async fn load_bundle(
  store : &DocumentStore,
  root~ : ArrayView[String] = [],
  options~ : @okf.Options = @okf.Options::default(),
  profiles~ : ArrayView[&@okf.Profile] = [],
) -> @okf.Bundle raise StoreError {
  let set = load_set(store, under=root)
  @okf.load_bundle(set, root~, options~, profiles~)
}

///|
/// Writes each change of a plan to a store and returns the number of writes
/// and deletes. A plan never holds an update that changes nothing.
pub async fn apply(
  plan : @edit.EditPlan,
  store : &DocumentStore,
) -> Int32 raise StoreError {
  let mut count = 0
  for change in plan.changes() {
    match change {
      Create(path~, text~) | Update(path~, after=text, ..) =>
        store.write_text(path, text)
      CreateBinary(path~, bytes~) => store.write_bytes(path, bytes)
      Delete(path~) => store.delete(path)
    }
    count += 1
  }
  count
}

///|
/// Whether a derived index matches the knowledge it was built from.
pub(all) enum IndexStatus {
  /// The index was never built.
  Missing
  Fresh
  /// The index differs from the knowledge, with a reason.
  Stale(String)
} derive(Eq, Debug)

///|
/// The metadata that an index records at build time.
pub(all) struct IndexMetadata {
  schema_version : Int32
  built_at : @okf.Instant
  document_count : Int32
} derive(Eq, Debug)

///|
/// Raised by index and search providers.
pub(all) suberror IndexError {
  /// The index was never built.
  NotBuilt
  /// Any other failure.
  IndexFailed(String)
} derive(Eq, Debug)

///|
/// A derived index over loaded knowledge. An implementation can keep it in
/// memory, or in a database such as SQLite or RocksDB.
pub(open) trait IndexProvider {
  /// Builds the index from the knowledge, recording the instant of `clock`.
  async fn build(Self, @okf.Knowledge, &@okf.Clock) -> IndexMetadata raise IndexError
  /// Compares the index with the knowledge.
  async fn status(Self, @okf.Knowledge) -> IndexStatus raise IndexError
  /// The metadata of the last build.
  async fn metadata(Self) -> IndexMetadata? raise IndexError
  /// The concepts that match every filter.
  async fn documents(Self, ArrayView[@okf.Filter]) -> Array[@okf.DocKey] raise IndexError
  /// The values of a frontmatter key with their counts.
  async fn facet(Self, String) -> Array[(String, Int32)] raise IndexError
  /// The links from a document.
  async fn links_from(Self, @okf.DocKey) -> Array[@okf.Edge] raise IndexError
  /// The resolved links to a document.
  async fn backlinks(Self, @okf.DocKey) -> Array[@okf.Edge] raise IndexError
  /// The outline of a document.
  async fn headings(Self, @okf.DocKey) -> Array[@okf.Heading] raise IndexError
  /// The `sources` of a document.
  async fn sources(Self, @okf.DocKey) -> Array[@okf.Source] raise IndexError
}

///|
/// Ranked search over an index.
pub(open) trait SearchProvider {
  async fn search(Self, @okf.SearchRequest) -> Array[@okf.SearchHit] raise IndexError
}

///|
/// A fingerprint of the documents of the knowledge, to detect changes.
pub fn fingerprint(knowledge : @okf.Knowledge) -> Map[@okf.DocKey, Int32] {
  let out : Map[@okf.DocKey, Int32] = Map([])
  for pair in knowledge.documents() {
    out[@okf.DocKey::of(pair.0, pair.1)] = pair.1.text().hash()
  }
  out
}

///|
pub extend EntryKind with Eq::{not_equal, equal}

///|
pub extend EntryKind with @debug.Debug::{to_repr}

///|
pub extend StoreEntry with Eq::{not_equal, equal}

///|
pub extend StoreEntry with @debug.Debug::{to_repr}

///|
pub extend StoreError with Eq::{not_equal, equal}

///|
pub extend StoreError with @debug.Debug::{to_repr}

///|
pub extend IndexStatus with Eq::{not_equal, equal}

///|
pub extend IndexStatus with @debug.Debug::{to_repr}

///|
pub extend IndexMetadata with Eq::{not_equal, equal}

///|
pub extend IndexMetadata with @debug.Debug::{to_repr}

///|
pub extend IndexError with Eq::{not_equal, equal}

///|
pub extend IndexError with @debug.Debug::{to_repr}
