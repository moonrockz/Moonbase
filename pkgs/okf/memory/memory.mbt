///|
/// A document store in memory. Its contents are also available synchronously,
/// so the pure core can use them on every target, including wasm-gc.
struct MemoryStore {
  files : Ref[Map[@okf.StorePath, (@okf.FileContent, @okf.Instant?)]]
  clock : &@okf.Clock?
  read_only : Bool
}

///|
/// A store with the files of `set`. With `clock`, writes record a
/// modification time. With `read_only=true`, writes and deletes fail.
pub fn MemoryStore::MemoryStore(
  set~ : @okf.DocumentSet = @okf.DocumentSet([]),
  clock? : &@okf.Clock,
  read_only~ : Bool = false,
) -> MemoryStore {
  let files : Map[@okf.StorePath, (@okf.FileContent, @okf.Instant?)] = Map([])
  for entry in set.entries() {
    files[entry.path] = (entry.content, None)
  }
  { files: Ref(files), clock, read_only, }
}

///|
/// The current contents as a document set.
pub fn MemoryStore::snapshot(self : MemoryStore) -> @okf.DocumentSet {
  @okf.DocumentSet(
    self.files.val
    .iter()
    .map(pair => @okf.FileEntry::{ path: pair.0, content: pair.1.0, })
    .collect(),
  )
}

///|
/// Writes text synchronously.
pub fn MemoryStore::put(
  self : MemoryStore,
  path : @okf.StorePath,
  text : String,
) -> Unit {
  let now = match self.clock {
    Some(c) => Some(c.now())
    None => None
  }
  self.files.val[path] = (Text(text), now)
}

///|
fn MemoryStore::write(
  self : MemoryStore,
  path : @okf.StorePath,
  content : @okf.FileContent,
) -> Unit raise @provider.StoreError {
  if self.read_only {
    raise PermissionDenied(path.to_string())
  }
  let now = match self.clock {
    Some(c) => Some(c.now())
    None => None
  }
  self.files.val[path] = (content, now)
}

///|
pub impl @provider.DocumentStore for MemoryStore with fn list(self, dir) {
  let dir = dir.to_owned()
  let names : Map[String, @provider.EntryKind] = Map([])
  for pair in self.files.val {
    let path = pair.0
    if dir.is_empty() || path.is_under(dir) {
      let segments = path.segments()
      let name = segments[dir.length()]
      let kind : @provider.EntryKind = if segments.length() == dir.length() + 1 {
        File
      } else {
        Directory
      }
      names[name] = kind
    }
  }
  if names.is_empty() && !dir.is_empty() {
    raise NotFound(dir.join("/"))
  }
  let out = names
    .iter()
    .map(p => @provider.StoreEntry::{ name: p.0, kind: p.1, })
    .collect()
  out.sort_by((a, b) => @okf.lexical_compare(a.name, b.name))
  out
}

///|
pub impl @provider.DocumentStore for MemoryStore with fn read_text(self, path) {
  match self.files.val.get(path) {
    Some((content, _)) => content.text()
    None => raise NotFound(path.to_string())
  }
}

///|
pub impl @provider.DocumentStore for MemoryStore with fn read_bytes(self, path) {
  match self.files.val.get(path) {
    Some((Bytes(b), _)) => b
    Some((Text(t), _)) => @okf.encode_utf8(t)
    None => raise NotFound(path.to_string())
  }
}

///|
pub impl @provider.DocumentStore for MemoryStore with fn write_text(
  self,
  path,
  text,
) {
  self.write(path, Text(text))
}

///|
pub impl @provider.DocumentStore for MemoryStore with fn write_bytes(
  self,
  path,
  bytes,
) {
  self.write(path, Bytes(bytes))
}

///|
pub impl @provider.DocumentStore for MemoryStore with fn delete(self, path) {
  if self.read_only {
    raise PermissionDenied(path.to_string())
  }
  self.files.val.remove(path)
}

///|
pub impl @provider.DocumentStore for MemoryStore with fn modified(self, path) {
  match self.files.val.get(path) {
    Some((_, at)) => at
    None => raise NotFound(path.to_string())
  }
}

///|
priv struct IndexState {
  knowledge : @okf.Knowledge
  graph : @okf.Graph
  metadata : @provider.IndexMetadata
  prints : Map[@okf.DocKey, Int32]
}

///|
/// An index and search provider in memory, backed by the link graph.
struct MemoryIndex {
  state : Ref[IndexState?]
  resolver : &@okf.LinkResolver?
}

///|
/// The schema version of the in-memory index.
pub let memory_schema_version : Int32 = 1

///|
pub fn MemoryIndex::MemoryIndex(resolver? : &@okf.LinkResolver) -> MemoryIndex {
  { state: Ref(None), resolver, }
}

///|
/// Builds the index synchronously.
pub fn MemoryIndex::build_now(
  self : MemoryIndex,
  knowledge : @okf.Knowledge,
  clock : &@okf.Clock,
) -> @provider.IndexMetadata {
  let graph = @okf.Graph::build(knowledge, resolver?=self.resolver)
  let metadata : @provider.IndexMetadata = {
    schema_version: memory_schema_version,
    built_at: clock.now(),
    document_count: knowledge.documents().length(),
  }
  self.state.val = Some({
    knowledge,
    graph,
    metadata,
    prints: @provider.fingerprint(knowledge),
  })
  metadata
}

///|
fn MemoryIndex::current(
  self : MemoryIndex,
) -> IndexState raise @provider.IndexError {
  match self.state.val {
    Some(s) => s
    None => raise NotBuilt
  }
}

///|
/// Searches synchronously.
pub fn MemoryIndex::search_now(
  self : MemoryIndex,
  request : @okf.SearchRequest,
) -> Array[@okf.SearchHit] raise @provider.IndexError {
  @okf.search_knowledge(self.current().knowledge, request)
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn build(
  self,
  knowledge,
  clock,
) {
  self.build_now(knowledge, clock)
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn status(self, knowledge) {
  match self.state.val {
    None => Missing
    Some(s) => {
      let now = @provider.fingerprint(knowledge)
      if now.length() != s.prints.length() {
        return Stale(
          "the document count changed from \{s.prints.length()} to \{now.length()}",
        )
      }
      for pair in now {
        match s.prints.get(pair.0) {
          Some(h) if h == pair.1 => ()
          Some(_) => return Stale("\{pair.0.to_string()} changed")
          None => return Stale("\{pair.0.to_string()} is new")
        }
      }
      Fresh
    }
  }
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn metadata(self) {
  match self.state.val {
    Some(s) => Some(s.metadata)
    None => None
  }
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn documents(
  self,
  filters,
) {
  self.current().knowledge.filter(filters).map(p => @okf.DocKey::of(p.0, p.1))
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn facet(self, key) {
  self.current().knowledge.facet(key)
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn links_from(self, key) {
  self.current().graph.outbound(key)
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn backlinks(self, key) {
  self.current().graph.backlinks(key)
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn headings(self, key) {
  match self.current().knowledge.document(key) {
    Some(doc) => doc.outline()
    None => []
  }
}

///|
pub impl @provider.IndexProvider for MemoryIndex with fn sources(self, key) {
  match self.current().knowledge.document(key) {
    Some(doc) => doc.metadata().sources()
    None => []
  }
}

///|
pub impl @provider.SearchProvider for MemoryIndex with fn search(self, request) {
  self.search_now(request)
}

///|
pub extend MemoryStore with @moonrockz/okf/provider.DocumentStore::{
  read_bytes,
  list,
  write_bytes,
  delete,
  modified,
  read_text,
  write_text,
}

///|
pub extend MemoryIndex with @moonrockz/okf/provider.IndexProvider::{
  headings,
  backlinks,
  build,
  status,
  links_from,
  sources,
  metadata,
  documents,
  facet,
}

///|
pub extend MemoryIndex with @moonrockz/okf/provider.SearchProvider::{search}
