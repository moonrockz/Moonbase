///|
fn doc(path : String, text : String) -> @okf.Document raise {
  @okf.Document(@okf.BundlePath(path), @okf.StorePath(path), text)
}

///|
test "split_header finds the block and the body line" {
  let h = @okf.split_header("---\ntitle: A\n---\n# A\n")
  @debug.debug_inspect(h.shape, content="Block(raw=\"title: A\\n\")")
  @debug.debug_inspect(
    h.body,
    content=(
      #|"# A\n"
    ),
  )
  @debug.debug_inspect(h.body_line, content="4")
}

///|
test "split_header with CRLF and a dots closer" {
  let h = @okf.split_header("---\r\ntype: Metric\r\n...\r\nBody")
  @debug.debug_inspect(h.body_line, content="4")
  @debug.debug_inspect(
    h.body,
    content=(
      #|"Body"
    ),
  )
}

///|
test "unterminated and missing blocks" {
  @debug.debug_inspect(
    @okf.split_header("---\ntitle: A\n").shape,
    content="Unterminated",
  )
  @debug.debug_inspect(@okf.split_header("# A\n").shape, content="NoBlock")
}

///|
test "scan_entries locates top-level keys and their lines" {
  let entries = @okf.scan_entries(
    "type: Metric\ntags:\n  - a\n  - b\n# note\nstatus: draft # later\n",
  )
  @debug.debug_inspect(
    entries.map(e => (e.key, e.inline, e.first_line, e.last_line)),
    content=(
      #|[
      #|  ("type", "Metric", 0, 0),
      #|  ("tags", "", 1, 3),
      #|  ("status", "draft", 5, 5),
      #|]
    ),
  )
}

///|
test "metadata keeps scalar text and key order" {
  let m = @okf.Metadata(
    "type: Metric\nstale_after: 2026-09-01T00:00:00Z\ncount: 007\nowner_team: data\n",
  )
  @debug.debug_inspect(
    m.keys(),
    content="[\"type\", \"stale_after\", \"count\", \"owner_team\"]",
  )
  @debug.debug_inspect(m.text("count"), content="Some(\"007\")")
  @debug.debug_inspect(
    m.text("stale_after"),
    content="Some(\"2026-09-01T00:00:00Z\")",
  )
  @debug.debug_inspect(m.line_of("owner_team"), content="Some(5)")
}

///|
test "metadata errors carry file lines" {
  let d = doc("/a.md", "---\ntype: A\ntitle: [unclosed\n---\nBody\n")
  @debug.debug_inspect(d.written_metadata() is None, content="true")
  guard d.metadata_error() is Some(InvalidYaml(line~, ..)) else {
    fail("expected an invalid YAML error")
  }
  @debug.debug_inspect(line >= 3, content="true")
}

///|
test "duplicate keys are frontmatter errors" {
  let d = doc("/a.md", "---\ntitle: A\ntitle: B\n---\n")
  @debug.debug_inspect(d.metadata_error() is Some(_), content="true")
}

///|
test "lenient accessors" {
  let m = @okf.Metadata("tags: finance\nflag: Yes\nn: 42\n")
  @debug.debug_inspect(m.texts("tags"), content="[\"finance\"]")
  @debug.debug_inspect(m.bool("flag"), content="Some(true)")
  @debug.debug_inspect(m.int("n"), content="Some(42)")
}

///|
test "typed fields, trust tier and staleness" {
  let m = @okf.Metadata(
    (
      #|type: Metric
      #|sources:
      #|  - id: ga4-schema
      #|    resource: https://example.com/schema
      #|  - title: no resource
      #|verified: {by: "human:jsmith", at: "2026-06-30T14:00:00Z"}
      #|stale_after: 2026-09-01T00:00:00Z
      #|status: archived
    ),
  )
  @debug.debug_inspect(
    m.sources().map(s => (s.id, s.resource)),
    content=(
      #|[(Some("ga4-schema"), "https://example.com/schema")]
    ),
  )
  @debug.debug_inspect(m.verified().length(), content="1")
  @debug.debug_inspect(m.trust_tier(), content="HumanReviewed")
  @debug.debug_inspect(m.status(), content="Some(Unknown(\"archived\"))")
  let now = @okf.Instant::parse("2026-09-02T00:00:00Z").unwrap()
  @debug.debug_inspect(m.is_stale(now), content="true")
  let before = @okf.Instant::parse("2026-08-31T23:59:59+00:00").unwrap()
  @debug.debug_inspect(m.is_stale(before), content="false")
}

///|
test "status default and date-only option" {
  let m = @okf.Metadata("type: A\nstale_after: 2026-09-01\n")
  @debug.debug_inspect(m.effective_status(), content="Some(Stable)")
  let no_default = @okf.Options::default().update(status_default=None)
  @debug.debug_inspect(m.effective_status(options=no_default), content="None")
  let now = @okf.Instant::parse("2026-09-01T00:00:00Z").unwrap()
  @debug.debug_inspect(m.is_stale(now), content="false")
  let dates = @okf.Options::default().update(date_only_instants=true)
  @debug.debug_inspect(m.is_stale(now, options=dates), content="true")
}

///|
test "instants with offsets and dates" {
  let a = @okf.Instant::parse("2026-06-30T14:00:00Z").unwrap()
  let b = @okf.Instant::parse("2026-06-30T16:00:00+02:00").unwrap()
  @debug.debug_inspect(a == b, content="true")
  @debug.debug_inspect(@okf.Instant::parse("2026-06-30"), content="None")
  @debug.debug_inspect(
    a.date_text(),
    content=(
      #|"2026-06-30"
    ),
  )
  @debug.debug_inspect(
    @okf.Instant::parse("2026-02-30T00:00:00Z"),
    content="None",
  )
}

///|
test "actors" {
  @debug.debug_inspect(
    @okf.Actor::parse("okf-agent/0.2"),
    content=(
      #|Producer(name="okf-agent", version="0.2")
    ),
  )
  @debug.debug_inspect(
    @okf.Actor::parse("human:jsmith@acme"),
    content="Human(\"jsmith@acme\")",
  )
  @debug.debug_inspect(
    @okf.Actor::parse("team:ga4-docs"),
    content="Other(\"team:ga4-docs\")",
  )
}

///|
test "document kinds and concept ids" {
  @debug.debug_inspect(
    @okf.kind_of(@okf.BundlePath("/index.md")),
    content="RootIndex",
  )
  @debug.debug_inspect(
    @okf.kind_of(@okf.BundlePath("/tables/index.md")),
    content="SubIndex",
  )
  @debug.debug_inspect(
    @okf.kind_of(@okf.BundlePath("/tables/log.md")),
    content="Log",
  )
  @debug.debug_inspect(
    @okf.kind_of(@okf.BundlePath("/tables/customers.md")),
    content="Concept",
  )
  let id = @okf.ConceptId("/tables/customers.md")
  @debug.debug_inspect(
    id,
    content=(
      #|{ text: "tables/customers" }
    ),
  )
  @debug.debug_inspect(id == @okf.ConceptId("tables/customers"), content="true")
}

///|
test "links have file lines and kinds" {
  let d = doc(
    "/tables/orders.md",
    (
      #|---
      #|type: Table
      #|---
      #|# Orders
      #|
      #|See [Customers](/tables/customers.md) and [rev](../metrics/revenue.md#daily).
      #|
      #|```
      #|[Customers](/tables/customers.md)
      #|```
      #|
      #|![Diagram](/assets/flow.png) <https://example.com> [top](#orders)
      #|
      #|[ref]: customers.md
      #|Use [the ref][ref].
    ),
  )
  @debug.debug_inspect(
    d.links().map(l => (l.text, l.destination, l.line, l.kind)),
    content=(
      #|[
      #|  ("Customers", "/tables/customers.md", 6, BundleRooted),
      #|  ("rev", "../metrics/revenue.md#daily", 6, Relative),
      #|  ("https://example.com", "https://example.com", 12, External),
      #|  ("top", "#orders", 12, Anchor),
      #|  ("the ref", "customers.md", 15, Relative),
      #|]
    ),
  )
}

///|
test "footnote citations join sources" {
  let d = doc(
    "/a.md",
    (
      #|---
      #|type: Metric
      #|sources:
      #|  - id: ga4-schema
      #|    resource: https://example.com/schema
      #|---
      #|The field is daily.[^ga4-schema]
      #|
      #|[^ga4-schema]: From the schema.
    ),
  )
  @debug.debug_inspect(d.links(), content="[]")
  @debug.debug_inspect(
    d.cited_sources().map(p => (p.0.label, p.0.line, p.1.map(s => s.resource))),
    content=(
      #|[("ga4-schema", 7, Some("https://example.com/schema"))]
    ),
  )
}
