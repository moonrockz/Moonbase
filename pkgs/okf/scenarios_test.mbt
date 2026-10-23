///|
fn set_of(files : Array[(String, String)]) -> @okf.DocumentSet raise {
  @okf.DocumentSet::of_texts(files)
}

///|
test "GitHub source URL parts" {
  let parts = @okf.GitHubSource::parse(
    "https://github.com/finos/morphir/blob/ab8d5c91/spec/ir.md",
  )
  assert_eq(
    parts.map(p => (p.org, p.repo, p.commit, p.path)),
    Some(("finos", "morphir", "ab8d5c91", "spec/ir.md")),
  )
  assert_eq(
    @okf.GitHubSource::parse("https://github.com/finos/morphir/blob/main/x.md"),
    None,
  )
}

///|
test "typed references: a source that points to a concept, and an unresolved one" {
  let k = @okf.discover(
    set_of([
      ("index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("references/ga4-docs.md", "---\ntype: Reference\n---\n"),
      (
        "tables/events.md", "---\ntype: Table\nsources:\n  - resource: /references/ga4-docs.md\n  - resource: /references/missing.md\n  - resource: all queries in project X\n---\n",
      ),
    ]),
  )
  let b = k.bundles()[0]
  guard b.document(@okf.BundlePath("/tables/events.md")) is Some(doc) else {
    fail("no doc")
  }
  let refs = @okf.typed_references(k, b, doc)
  assert_eq(refs.map(r => r.is_resolved()), [true, false, true])
  assert_true(refs[0].target is ToDocument(_))
  assert_true(refs[2].target is FreeText(_))
}

///|
test "a cross-bundle link resolves and gives a backlink" {
  let k = @okf.discover(
    set_of([
      ("bundles/morphir/ir/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("bundles/morphir/ir/names.md", "---\ntype: Design Note\n---\n"),
      ("bundles/morphir/cli/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      (
        "bundles/morphir/cli/use.md", "---\ntype: Design Note\n---\nSee [names](../ir/names.md).\n",
      ),
    ]),
    under=["bundles"],
  )
  let g = @okf.Graph::build(k)
  let names : @okf.DocKey = {
    bundle: "morphir/ir",
    path: @okf.BundlePath("/names.md"),
  }
  assert_eq(g.linked_from(names).map(key => key.to_string()), [
    "morphir/cli:/use.md",
  ])
}

///|
test "a resolver that knows files outside the bundle" {
  let set = set_of([
    ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    ("kb/a.md", "---\ntype: Note\n---\nSee [spec](../spec/x.md).\n"),
  ])
  let k = @okf.discover(set)
  assert_eq(@okf.Graph::build(k).broken().length(), 1)
  let resolver : &@okf.LinkResolver = @okf.PathListResolver::{
    paths: [@okf.StorePath("spec/x.md")],
  }
  assert_eq(@okf.Graph::build(k, resolver~).broken().length(), 0)
}

///|
test "an ambiguous bare bundle name" {
  let k = @okf.discover(
    set_of([
      ("morphir/ir/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("finos/ir/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    ]),
  )
  guard k.bundle("ir") is Ambiguous(list) else {
    fail("expected an ambiguous lookup")
  }
  assert_eq(list.map(b => b.label()), ["finos/ir", "morphir/ir"])
  assert_true(k.bundle("morphir/ir") is Found(_))
}

///|
test "padded record IDs and duplicate IDs" {
  let reg = @okf.Register("decision", "Decision Record")
  let b = @okf.load_bundle(
    set_of([
      ("decisions/42-use-yaml.md", "---\ntype: Decision Record\n---\n"),
      ("decisions/0042-also.md", "---\ntype: Decision Record\n---\n"),
      ("decisions/7-other.md", "---\ntype: decision record\n---\n"),
    ]),
  )
  let records = reg.records(b)
  assert_eq(records.map(r => r.id.unwrap_or("")), ["0042", "0042", "0007"])
  assert_eq(reg.duplicates(records).map(d => (d.0, d.1.length())), [("0042", 2)])
  assert_true(reg.find(records, "42") is Ambiguous(_))
}

///|
priv struct NamedOnly {}

///|
impl @okf.Profile for NamedOnly with fn name(_) {
  "named-only"
}

///|
priv struct StateProfile {
  values : Array[String]
}

///|
impl @okf.Profile for StateProfile with fn name(self) {
  "state-" + self.values.join("-")
}

///|
impl @okf.Profile for StateProfile with fn vocabulary(self) {
  [@okf.KeyDefinition("state", values=self.values)]
}

///|
test "an empty profile changes nothing, and conflicting profiles are reported" {
  let set = set_of([
    ("a.md", "---\ntype: Note\n---\n"),
    ("b.md", "# No frontmatter\n"),
  ])
  let plain = @okf.load_bundle(set)
  let with_profile = @okf.load_bundle(set, profiles=[NamedOnly::{ }])
  assert_eq(
    with_profile.documents().map(d => d.metadata().keys()),
    plain.documents().map(d => d.metadata().keys()),
  )
  let a : &@okf.Profile = StateProfile::{ values: ["open", "closed"], }
  let b : &@okf.Profile = StateProfile::{ values: ["Backlog"], }
  assert_eq(@okf.profile_conflicts([a, b]), [
    KeyConflict(key="state", first="state-open-closed", second="state-Backlog"),
  ])
  assert_eq(@okf.profile_conflicts([a, a]), [])
}

///|
test "findings carry their fields and keep a stable order" {
  let k = @okf.discover(
    set_of([
      ("index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("tables/orders.md", "---\ntitle: Orders\n---\n"),
      ("tables/index.md", "---\ntitle: bad\n---\n"),
      ("log.md", "# Log\n\n## Yesterday\n"),
    ]),
  )
  let clock = @okf.FixedClock(@okf.Instant::of_millis(0L))
  let first = @okf.validate(k, [@okf.okf_v02_conformance()], clock)
  let second = @okf.validate(k, [@okf.okf_v02_conformance()], clock)
  assert_eq(first.findings(), second.findings())
  let rows = first
    .findings()
    .map(f => (f.severity.to_string(), f.rule, f.path))
    .iter()
    .collect()
  assert_eq(rows, [
    ("error", "log-undated-section", "/log.md"),
    ("error", "subindex-has-frontmatter", "/tables/index.md"),
    ("error", "concept-missing-type", "/tables/orders.md"),
  ])
}

///|
test "a generated root index keeps okf_version" {
  let b = @okf.load_bundle(
    set_of([
      ("index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("a.md", "---\ntype: Note\ntitle: A\n---\n"),
      ("sub/b.md", "---\ntype: Note\n---\n"),
    ]),
  )
  assert_eq(
    @okf.generate_index(b, describe=_ => Some("More notes")),
    "---\nokf_version: \"0.2\"\n---\n\n# Note\n\n* [A](a.md)\n\n# Subdirectories\n\n* [sub](sub/index.md) - More notes\n",
  )
}

///|
test "root-only logs report nested logs as ignored" {
  let set = set_of([("log.md", "# Log\n"), ("tables/log.md", "# Log\n")])
  let options = @okf.Options::default().update(nested_logs=RootOnly)
  let b = @okf.load_bundle(set, options~)
  assert_eq(b.logs().map(d => d.path().to_string()), ["/log.md"])
  assert_eq(b.ignored_logs().map(p => p.to_string()).iter().collect(), [
    "/tables/log.md",
  ])
  assert_eq(@okf.load_bundle(set).logs().length(), 2)
}

///|
test "v0.1 timestamp reads as generated.at only with the option" {
  let m = @okf.Metadata("type: A\ntimestamp: 2026-06-12T00:00:00Z\n")
  assert_eq(m.generated(), None)
  let v01 = @okf.Options::default().update(v01_fields=true)
  assert_eq(
    m.generated(options=v01).map(g => g.at),
    Some(Some("2026-06-12T00:00:00Z")),
  )
}

///|
test "derived metadata is marked and does not change the text" {
  let set = set_of([("specs/a/spec.md", "# a Specification\n")])
  let b = @okf.load_bundle(set, profiles=[TypeFromPath::{ }])
  guard b.document(@okf.BundlePath("/specs/a/spec.md")) is Some(doc) else {
    fail("no doc")
  }
  assert_eq(doc.concept_type(), Some("Specification"))
  assert_true(doc.is_derived())
  assert_eq(doc.text(), "# a Specification\n")
}

///|
priv struct TypeFromPath {}

///|
impl @okf.Profile for TypeFromPath with fn name(_) {
  "type-from-path"
}

///|
impl @okf.Profile for TypeFromPath with fn derive_metadata(_, doc) {
  if doc.path().name() == "spec.md" {
    Some(@okf.Fields([("type", Scalar("Specification"))]))
  } else {
    None
  }
}
