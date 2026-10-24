///|
/// The target of a link after resolution and existence checks.
pub(all) enum Target {
  /// A document of a loaded bundle.
  Doc(DocKey)
  /// A file that the resolver knows, outside the loaded documents.
  File(StorePath)
  /// A URI with a scheme.
  Uri(String)
  /// A fragment of the same document.
  Fragment(String)
  /// A target that does not exist. The path is `None` when the destination
  /// cannot name a store file.
  Broken(StorePath?)
} derive(Eq, Debug)

///|
/// One link of the graph.
pub(all) struct Edge {
  from : DocKey
  link : Link
  target : Target
  /// True when the target path leaves the bundle of the source document.
  escapes : Bool
} derive(Eq, Debug)

///|
pub fn Edge::is_broken(self : Edge) -> Bool {
  self.target is Broken(_)
}

///|
/// The directed link graph of a set of bundles.
struct Graph {
  edges : ReadOnlyArray[Edge]
  outbound : Map[DocKey, Array[Int32]]
  inbound : Map[DocKey, Array[Int32]]
}

///|
/// Builds the graph: each body link of each document, plus the links that
/// profiles add. `resolver` answers for targets outside the loaded documents.
pub fn Graph::build(
  knowledge : Knowledge,
  resolver? : &LinkResolver,
  profiles~ : ArrayView[&Profile] = [],
) -> Graph {
  let edges : Array[Edge] = []
  let outbound : Map[DocKey, Array[Int32]] = Map([])
  let inbound : Map[DocKey, Array[Int32]] = Map([])
  for bundle in knowledge.bundles() {
    for doc in bundle.documents() {
      let from = DocKey::of(bundle, doc)
      let links = doc.links()
      for profile in profiles {
        for link in profile.relations(bundle, doc) {
          links.push(link)
        }
      }
      for link in links {
        let (target, _) = target_of(knowledge, bundle, doc, link, resolver)
        let escapes = link_escapes(bundle, doc, link)
        let index = edges.length()
        edges.push({ from, link, target, escapes, })
        match outbound.get(from) {
          Some(list) => list.push(index)
          None => outbound[from] = [index]
        }
        match target {
          Doc(key) =>
            match inbound.get(key) {
              Some(list) => list.push(index)
              None => inbound[key] = [index]
            }
          _ => ()
        }
      }
    }
  }
  { edges: ReadOnlyArray::from_array(edges), outbound, inbound, }
}

///|
fn target_of(
  knowledge : Knowledge,
  bundle : Bundle,
  doc : Document,
  link : Link,
  resolver : &LinkResolver?,
) -> (Target, Bool) {
  match resolve_link(bundle, doc, link) {
    ExternalUri(uri) => (Uri(uri), false)
    SameDocument(fragment) => (Fragment(fragment), false)
    Unresolvable(_) => (Broken(None), false)
    StoreTarget(path~, escapes~, ..) =>
      match knowledge.document_at(path) {
        Some((b, d)) => (Doc(DocKey::of(b, d)), escapes)
        None => {
          let known = match resolver {
            Some(r) => r.exists(path)
            None => false
          }
          let asset = match knowledge.bundle_at(path) {
            Some(b) =>
              match b.bundle_path_of(path) {
                Some(rel) => b.assets().contains(rel)
                None => false
              }
            None => false
          }
          if known || asset {
            (File(path), escapes)
          } else {
            (Broken(Some(path)), escapes)
          }
        }
      }
  }
}

///|
pub fn Graph::edges(self : Graph) -> ReadOnlyArray[Edge] {
  self.edges
}

///|
/// The links from a document, in document order.
pub fn Graph::outbound(self : Graph, key : DocKey) -> Array[Edge] {
  match self.outbound.get(key) {
    Some(list) => list.map(i => self.edges[i])
    None => []
  }
}

///|
/// The resolved links that point to a document.
pub fn Graph::backlinks(self : Graph, key : DocKey) -> Array[Edge] {
  match self.inbound.get(key) {
    Some(list) => list.map(i => self.edges[i])
    None => []
  }
}

///|
/// The documents that link to a document, without duplicates, sorted.
pub fn Graph::linked_from(self : Graph, key : DocKey) -> Array[DocKey] {
  let keys = []
  for edge in self.backlinks(key) {
    if !keys.contains(edge.from) {
      keys.push(edge.from)
    }
  }
  keys.sort()
  keys
}

///|
/// Every broken link.
pub fn Graph::broken(self : Graph) -> Array[Edge] {
  self.edges.iter().filter(e => e.is_broken()).collect()
}

///|
/// The concepts that no other document links to. With
/// `count_index_links=false`, links from `index.md` files do not count.
pub fn Graph::orphans(
  self : Graph,
  knowledge : Knowledge,
  count_index_links~ : Bool = knowledge.options().index_links_count,
) -> Array[DocKey] {
  let out = []
  for pair in knowledge.concepts() {
    let (bundle, doc) = pair
    let key = DocKey::of(bundle, doc)
    let linked = self
      .backlinks(key)
      .any(edge => {
        edge.from != key &&
        (count_index_links || !kind_of(edge.from.path).is_index())
      })
    if !linked {
      out.push(key)
    }
  }
  out
}

///|
pub extend Target with Eq::{not_equal, equal}

///|
pub extend Target with @debug.Debug::{to_repr}

///|
pub extend Edge with Eq::{not_equal, equal}

///|
pub extend Edge with @debug.Debug::{to_repr}
