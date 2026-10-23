///|
/// The result of a lookup that can match nothing, one item or several items.
pub(all) enum Lookup[T] {
  NotFound
  Found(T)
  Ambiguous(Array[T])
} derive(Eq, Debug)

///|
pub fn[T] Lookup::to_option(self : Lookup[T]) -> T? {
  match self {
    Found(x) => Some(x)
    _ => None
  }
}

///|
fn[T] lookup_of(items : Array[T]) -> Lookup[T] {
  match items {
    [] => NotFound
    [x] => Found(x)
    _ => Ambiguous(items)
  }
}

///|
/// A set of bundles found under one directory, and the Markdown files that
/// belong to no bundle.
struct Knowledge {
  bundles : ReadOnlyArray[Bundle]
  strays : ReadOnlyArray[StorePath]
  options : Options
}

///|
/// Knowledge with the given bundles.
pub fn Knowledge::Knowledge(
  bundles : ArrayView[Bundle],
  strays~ : ArrayView[StorePath] = [],
  options~ : Options = Options::default(),
) -> Knowledge {
  {
    bundles: ReadOnlyArray::from_array(bundles.to_owned()),
    strays: ReadOnlyArray::from_array(strays.to_owned()),
    options,
  }
}

///|
/// Finds each bundle under the directory `under`: each directory whose
/// `index.md` frontmatter contains `okf_version`. It does not look for bundles
/// inside a bundle. Markdown files outside every bundle, except `README.md`,
/// are strays.
pub fn discover(
  set : DocumentSet,
  under~ : ArrayView[String] = [],
  options~ : Options = Options::default(),
  profiles~ : ArrayView[&Profile] = [],
) -> Knowledge {
  let under = under.to_owned()
  let roots : Array[Array[String]] = []
  for entry in set.entries() {
    guard under.is_empty() || entry.path.is_under(under) else { continue }
    guard entry.path.name().to_lower() == "index.md" else { continue }
    let header = split_header(entry.content.text())
    let declares = match header.shape {
      Block(raw~) => scan_entries(raw).any(e => e.key == "okf_version")
      _ => false
    }
    if declares {
      roots.push(entry.path.parent())
    }
  }
  roots.sort_by((a, b) => {
    if a.length() != b.length() {
      a.length().compare(b.length())
    } else {
      lexical_compare(a.join("/"), b.join("/"))
    }
  })
  let accepted : Array[Array[String]] = []
  for root in roots {
    let nested = accepted.any(outer => {
      outer.length() < root.length() &&
      root[:outer.length()].to_owned() == outer
    })
    if !nested {
      accepted.push(root)
    }
  }
  accepted.sort_by((a, b) => lexical_compare(a.join("/"), b.join("/")))
  let bundles = accepted.map(root => {
    let group = root[under.length():root.length() - 1].to_owned()
    load_bundle(set, root~, group~, options~, profiles~)
  })
  let strays = []
  for entry in set.entries() {
    guard under.is_empty() || entry.path.is_under(under) else { continue }
    guard is_markdown_name(entry.path.name()) else { continue }
    guard entry.path.name().to_lower() != "readme.md" else { continue }
    let inside = accepted.any(root => {
      root.is_empty() || entry.path.is_under(root)
    })
    if !inside {
      strays.push(entry.path)
    }
  }
  Knowledge(bundles, strays~, options~)
}

///|
pub fn Knowledge::bundles(self : Knowledge) -> ReadOnlyArray[Bundle] {
  self.bundles
}

///|
pub fn Knowledge::strays(self : Knowledge) -> ReadOnlyArray[StorePath] {
  self.strays
}

///|
pub fn Knowledge::options(self : Knowledge) -> Options {
  self.options
}

///|
/// Finds a bundle by its full label, or by its bare name when only one bundle
/// has that name.
pub fn Knowledge::bundle(self : Knowledge, label : String) -> Lookup[Bundle] {
  let exact = self.bundles.iter().filter(b => b.label() == label).collect()
  if !exact.is_empty() {
    return lookup_of(exact)
  }
  lookup_of(self.bundles.iter().filter(b => b.name() == label).collect())
}

///|
/// Every concept of every bundle, with its bundle.
pub fn Knowledge::concepts(self : Knowledge) -> Array[(Bundle, Document)] {
  let out = []
  for bundle in self.bundles {
    for doc in bundle.concepts() {
      out.push((bundle, doc))
    }
  }
  out
}

///|
/// Every document of every bundle, with its bundle.
pub fn Knowledge::documents(self : Knowledge) -> Array[(Bundle, Document)] {
  let out = []
  for bundle in self.bundles {
    for doc in bundle.documents() {
      out.push((bundle, doc))
    }
  }
  out
}

///|
/// The bundle that contains a store path, if any.
pub fn Knowledge::bundle_at(self : Knowledge, path : StorePath) -> Bundle? {
  let mut best : Bundle? = None
  for bundle in self.bundles {
    if bundle.root().is_empty() || path.is_under(bundle.root().iter().collect()) {
      match best {
        Some(b) if b.root().length() >= bundle.root().length() => ()
        _ => best = Some(bundle)
      }
    }
  }
  best
}

///|
/// The document at a store path, with its bundle.
pub fn Knowledge::document_at(
  self : Knowledge,
  path : StorePath,
) -> (Bundle, Document)? {
  match self.bundle_at(path) {
    Some(bundle) =>
      match bundle.bundle_path_of(path) {
        Some(rel) =>
          match bundle.document(rel) {
            Some(doc) => Some((bundle, doc))
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
/// A document key: the bundle label and the bundle path.
pub(all) struct DocKey {
  bundle : String
  path : BundlePath
} derive(Eq, Hash, Debug)

///|
pub impl Compare for DocKey with fn compare(self, other) {
  let c = lexical_compare(self.bundle, other.bundle)
  if c != 0 {
    c
  } else {
    self.path.compare(other.path)
  }
}

///|
pub fn DocKey::of(bundle : Bundle, doc : Document) -> DocKey {
  { bundle: bundle.label(), path: doc.path(), }
}

///|
pub fn DocKey::to_string(self : DocKey) -> String {
  self.bundle + ":" + self.path.to_string()
}

///|
/// The document for a key.
pub fn Knowledge::document(self : Knowledge, key : DocKey) -> Document? {
  match self.bundle(key.bundle) {
    Found(bundle) => bundle.document(key.path)
    _ => None
  }
}

///|
pub extend Lookup with Eq::{not_equal, equal}

///|
pub extend Lookup with @debug.Debug::{to_repr}

///|
pub extend DocKey with Eq::{not_equal, equal}

///|

///|
pub extend DocKey with Hash::{hash, hash_combine}

///|
pub extend DocKey with @debug.Debug::{to_repr}

///|
pub extend DocKey with Compare::{op_lt, op_le, op_ge, compare, op_gt}
