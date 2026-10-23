///|
/// An OKF bundle: a directory tree of Markdown documents and other files.
struct Bundle {
  root : ReadOnlyArray[String]
  name : String
  group : ReadOnlyArray[String]
  documents : ReadOnlyArray[Document]
  by_path : Map[BundlePath, Int32]
  assets : ReadOnlyArray[BundlePath]
  ignored_logs : ReadOnlyArray[BundlePath]
  options : Options
}

///|
/// Loads the bundle whose root is the directory `root` (store segments) of a
/// document set. Each Markdown file under the root becomes a document; other
/// files become assets.
pub fn load_bundle(
  set : DocumentSet,
  root~ : ArrayView[String] = [],
  name? : String,
  group~ : ArrayView[String] = [],
  options~ : Options = Options::default(),
  profiles~ : ArrayView[&Profile] = [],
) -> Bundle {
  let root = root.to_owned()
  let documents : Array[Document] = []
  let assets : Array[BundlePath] = []
  let ignored : Array[BundlePath] = []
  for entry in set.entries() {
    guard root.is_empty() || entry.path.is_under(root) else { continue }
    let rel = entry.path.segments().exact_view(start=root.length()).to_owned()
    let path = BundlePath::of_segments(rel)
    if !is_markdown_name(path.name()) {
      assets.push(path)
      continue
    }
    if options.nested_logs is RootOnly &&
      kind_of(path) is Log &&
      path.depth() > 0 {
      ignored.push(path)
      continue
    }
    let doc = Document(path, entry.path, entry.content.text())
    let doc = if doc.has_frontmatter_block() {
      doc
    } else {
      match derive_with(profiles, doc) {
        Some(fields) => doc.with_derived(fields)
        None => doc
      }
    }
    documents.push(doc)
  }
  let by_path : Map[BundlePath, Int32] = Map([])
  for i, doc in documents {
    by_path[doc.path()] = i
  }
  let name = match name {
    Some(n) => n
    None => if root.is_empty() { "." } else { root[root.length() - 1] }
  }
  {
    root: ReadOnlyArray::from_array(root),
    name,
    group: ReadOnlyArray::from_array(group.to_owned()),
    documents: ReadOnlyArray::from_array(documents),
    by_path,
    assets: ReadOnlyArray::from_array(assets),
    ignored_logs: ReadOnlyArray::from_array(ignored),
    options,
  }
}

///|
/// The store directory of the bundle root, as segments.
pub fn Bundle::root(self : Bundle) -> ReadOnlyArray[String] {
  self.root
}

///|
pub fn Bundle::name(self : Bundle) -> String {
  self.name
}

///|
/// The grouping directories between the discovery root and the bundle.
pub fn Bundle::group(self : Bundle) -> ReadOnlyArray[String] {
  self.group
}

///|
/// The group and the name, joined with `/`, for example `morphir/ir`.
pub fn Bundle::label(self : Bundle) -> String {
  if self.group.is_empty() {
    self.name
  } else {
    self.group.join("/") + "/" + self.name
  }
}

///|
/// The options that the bundle was loaded with.
pub fn Bundle::options(self : Bundle) -> Options {
  self.options
}

///|
/// Every document, sorted by path.
pub fn Bundle::documents(self : Bundle) -> ReadOnlyArray[Document] {
  self.documents
}

///|
pub fn Bundle::concepts(self : Bundle) -> Array[Document] {
  self.documents.iter().filter(d => d.kind() is Concept).collect()
}

///|
/// The root index and the sub-indexes.
pub fn Bundle::indexes(self : Bundle) -> Array[Document] {
  self.documents.iter().filter(d => d.kind().is_index()).collect()
}

///|
pub fn Bundle::logs(self : Bundle) -> Array[Document] {
  self.documents.iter().filter(d => d.kind() is Log).collect()
}

///|
pub fn Bundle::root_index(self : Bundle) -> Document? {
  self.documents.iter().find_first(d => d.kind() is RootIndex)
}

///|
/// The bundle-root `log.md`.
pub fn Bundle::root_log(self : Bundle) -> Document? {
  self.documents
  .iter()
  .find_first(d => d.kind() is Log && d.path().depth() == 0)
}

///|
/// Non-Markdown files.
pub fn Bundle::assets(self : Bundle) -> ReadOnlyArray[BundlePath] {
  self.assets
}

///|
/// Nested `log.md` files that the `RootOnly` option left out.
pub fn Bundle::ignored_logs(self : Bundle) -> ReadOnlyArray[BundlePath] {
  self.ignored_logs
}

///|
pub fn Bundle::document(self : Bundle, path : BundlePath) -> Document? {
  match self.by_path.get(path) {
    Some(i) => Some(self.documents[i])
    None => None
  }
}

///|
/// The concept with this Concept ID.
pub fn Bundle::concept(self : Bundle, id : ConceptId) -> Document? {
  match self.document(id.to_path()) {
    Some(doc) if doc.kind() is Concept => Some(doc)
    _ => None
  }
}

///|
/// The root index frontmatter: `okf_version` and profile bundle keys.
pub fn Bundle::config(self : Bundle) -> Metadata {
  match self.root_index() {
    Some(doc) => doc.metadata()
    None => Metadata::empty()
  }
}

///|
/// The `okf_version` of the root index.
pub fn Bundle::okf_version(self : Bundle) -> String? {
  self.config().text("okf_version")
}

///|
/// True when this library knows the declared OKF version.
pub fn Bundle::knows_version(self : Bundle) -> Bool {
  match self.okf_version() {
    Some(v) => v == "0.1" || v == "0.2"
    None => true
  }
}

///|
/// The store path of a bundle path.
pub fn Bundle::store_path_of(self : Bundle, path : BundlePath) -> StorePath {
  let segments = self.root.iter().collect()
  for s in path.segments() {
    segments.push(s)
  }
  StorePath::of_segments(segments)
}

///|
/// The bundle path of a store path, when it is inside this bundle.
pub fn Bundle::bundle_path_of(self : Bundle, path : StorePath) -> BundlePath? {
  if self.root.is_empty() {
    return Some(BundlePath::of_segments(path.segments().iter().collect()))
  }
  if path.is_under(self.root.iter().collect()) {
    Some(
      BundlePath::of_segments(
        path.segments().exact_view(start=self.root.length()).to_owned(),
      ),
    )
  } else {
    None
  }
}
