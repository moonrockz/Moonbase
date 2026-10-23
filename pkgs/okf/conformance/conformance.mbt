///|
fn check(condition : Bool, message : String) -> Unit raise {
  if !condition {
    fail("conformance: " + message)
  }
}

///|
fn path(text : String) -> @okf.StorePath raise {
  @okf.StorePath(text)
}

///|
/// Checks that a document store meets the `DocumentStore` contract. `store`
/// must be empty and writable. The checks write, read, list and delete files
/// under `prefix` (default: the root).
pub async fn check_store(
  store : &@provider.DocumentStore,
  prefix~ : ArrayView[String] = [],
) -> Unit {
  let prefix = prefix.to_owned()
  let p = (rel : String) => {
    if prefix.is_empty() {
      rel
    } else {
      prefix.join("/") + "/" + rel
    }
  }
  // Writes create parent directories.
  store.write_text(path(p("b.md")), "# B\r\n\r\nCRLF and ünïcödé 🌙\r\n")
  store.write_text(path(p("a.md")), "---\ntype: Note\n---\n# A\n")
  store.write_text(path(p("sub/deep/c.md")), "# C\n")
  store.write_bytes(path(p("sub/x.bin")), b"\x00\x01\xfe\xff")
  // Reads return what was written, byte for byte.
  check(
    store.read_text(path(p("b.md"))) ==
    "# B\r\n\r\nCRLF and ünïcödé 🌙\r\n",
    "read_text round trip",
  )
  check(
    store.read_bytes(path(p("sub/x.bin"))) == b"\x00\x01\xfe\xff",
    "read_bytes round trip",
  )
  // Listings are sorted and stable.
  let listing = store.list(prefix)
  let names = listing.map(e => e.name)
  check(
    names == ["a.md", "b.md", "sub"],
    "root listing is sorted: " + names.join(","),
  )
  check(
    listing[2].kind is Directory && listing[0].kind is File,
    "listing kinds",
  )
  check(store.list(prefix).map(e => e.name) == names, "listing is stable")
  let sub = prefix.copy()
  sub.push("sub")
  check(store.list(sub).map(e => e.name) == ["deep", "x.bin"], "sub listing")
  // A missing file is NotFound.
  let missing = try store.read_text(path(p("missing.md"))) catch {
    @provider.NotFound(_) => true
    _ => false
  } noraise {
    _ => false
  }
  check(missing, "reading a missing file raises NotFound")
  // Deleting removes a file; deleting a missing file is not an error.
  store.delete(path(p("a.md")))
  store.delete(path(p("a.md")))
  check(
    store.list(prefix).map(e => e.name) == ["b.md", "sub"],
    "delete removes the file",
  )
  // Loading reads the Markdown files into a document set.
  let set = @provider.load_set(store, under=prefix)
  check(set.contains(path(p("sub/deep/c.md"))), "load_set reads nested files")
  check(set.contains(path(p("sub/x.bin"))), "load_set reads assets")
  // Applying a plan writes only the changed documents.
  let plan = @edit.EditPlan([
    Update(path=path(p("b.md")), before="x", after="# B2\n"),
    Update(path=path(p("sub/deep/c.md")), before="# C\n", after="# C\n"),
  ])
  check(@provider.apply(plan, store) == 1, "apply writes one changed document")
  check(store.read_text(path(p("b.md"))) == "# B2\n", "apply wrote the change")
  // Paths that escape the root are refused.
  let refused = try @provider.safe_path("..\\outside.md") catch {
    InvalidPath(_) => true
    _ => false
  } noraise {
    _ => false
  }
  check(refused, "an escaping path is refused")
}

///|
fn sample_knowledge(revenue : String) -> @okf.Knowledge raise {
  @okf.discover(
    @okf.DocumentSet::of_texts([
      (
        "kb/index.md", "---\nokf_version: \"0.2\"\n---\n# Metric\n\n* [Revenue](/metrics/revenue.md) - Revenue\n",
      ),
      ("kb/metrics/revenue.md", revenue),
      (
        "kb/metrics/margin.md", "---\ntype: Metric\ntitle: Margin\ndescription: Gross margin\ntags: [finance]\nsources:\n  - resource: https://example.com/margin\n---\n# Margin\n\nUses [revenue](revenue.md).\n\n## Formula\n",
      ),
    ]),
  )
}

///|
fn revenue_text(description : String) -> String {
  "---\ntype: Metric\ntitle: Revenue\ndescription: \{description}\ntags: [finance, daily]\n---\n# Revenue\n\nRevenue per day.\n"
}

///|
/// Checks that an index provider meets the `IndexProvider` contract. `index`
/// must not be built yet.
pub async fn check_index(index : &@provider.IndexProvider) -> Unit {
  let knowledge = sample_knowledge(revenue_text("Revenue"))
  check(index.status(knowledge) is Missing, "an unbuilt index is missing")
  let clock = @okf.FixedClock::at("2026-10-23T00:00:00Z")
  let meta = index.build(knowledge, clock)
  check(meta.built_at == clock.now(), "metadata records the build instant")
  check(meta.document_count == 3, "metadata records the document count")
  check(index.metadata() == Some(meta), "metadata is reported")
  check(index.status(knowledge) is Fresh, "a built index is fresh")
  let finance = index.documents([HasTag("finance")])
  check(finance.length() == 2, "documents filter by tag")
  let revenue_key : @okf.DocKey = {
    bundle: "kb",
    path: @okf.BundlePath("/metrics/revenue.md"),
  }
  let graph = @okf.Graph::build(knowledge)
  let expected = graph.backlinks(revenue_key).map(e => e.from)
  let actual = index.backlinks(revenue_key).map(e => e.from)
  expected.sort()
  actual.sort()
  check(
    actual == expected,
    "backlinks equal the link graph: \{actual.length()} vs \{expected.length()}",
  )
  let margin_key : @okf.DocKey = {
    bundle: "kb",
    path: @okf.BundlePath("/metrics/margin.md"),
  }
  check(index.links_from(margin_key).length() == 1, "links_from")
  check(
    index.headings(margin_key).map(h => h.text) == ["Margin", "Formula"],
    "headings",
  )
  check(index.sources(margin_key).length() == 1, "sources")
  check(index.facet("type") == [("Metric", 2)], "facet")
  let changed = sample_knowledge(revenue_text("Revenue in USD"))
  check(
    index.status(changed) is Stale(_),
    "a changed document makes the index stale",
  )
}

///|
/// Checks that a search provider meets the `SearchProvider` contract over the
/// knowledge that `prepare` loads into it.
pub async fn check_search(
  search : &@provider.SearchProvider,
  prepare : async (@okf.Knowledge) -> Unit,
) -> Unit {
  let knowledge = sample_knowledge(revenue_text("Revenue"))
  prepare(knowledge)
  let request = @okf.SearchRequest("revenue", limit=5)
  let first = search.search(request)
  let second = search.search(request)
  check(first == second, "the same request gives the same results")
  check(first.length() == 2, "both concepts mention revenue: \{first.length()}")
  check(
    first[0].key.path.to_string() == "/metrics/revenue.md",
    "the title match ranks first",
  )
  check(first[0].score >= first[1].score, "results are ordered by score")
  check(
    search.search(@okf.SearchRequest("revenue", limit=1)).length() == 1,
    "the limit applies",
  )
  let filtered = search.search(
    @okf.SearchRequest("revenue", filters=[HasTag("daily")]),
  )
  check(filtered.length() == 1, "filters apply")
}
