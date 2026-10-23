///|
let spec_text : String =
  #|# okf/documents Specification
  #|
  #|## Purpose
  #|
  #|Read OKF bundles into immutable values.
  #|
  #|## Requirements
  #|
  #|### Requirement: Concept IDs
  #|The library SHALL give each concept a Concept ID.
  #|
  #|#### Scenario: Concept ID from path
  #|- **WHEN** a bundle holds `/tables/customers.md`
  #|- **THEN** the concept has the Concept ID `tables/customers`
  #|- **AND** the ID compares equal to the same path
  #|

///|
let delta_text : String =
  #|# Spec Delta
  #|
  #|## MODIFIED Requirements
  #|
  #|### Requirement: Concept IDs
  #|The library SHALL give each concept a Concept ID without `.md`.
  #|
  #|#### Scenario: Concept ID from path
  #|- **WHEN** a bundle holds `/a.md`
  #|- **THEN** the ID is `a`
  #|
  #|## RENAMED Requirements
  #|
  #|- FROM: `### Requirement: Old name`
  #|- TO: `### Requirement: New name`
  #|

///|
fn tree() -> @okf.DocumentSet raise {
  @okf.DocumentSet::of_texts([
    ("openspec/config.yaml", "schema: spec-driven\n"),
    ("openspec/specs/okf/documents/spec.md", spec_text),
    (
      "openspec/changes/fix-ids/proposal.md", "## Why\n\nIDs keep the extension.\n\n## What Changes\n\n- Drop `.md`.\n",
    ),
    (
      "openspec/changes/fix-ids/tasks.md", "## 1. IDs\n\n- [x] 1.1 Drop the extension\n- [ ] 1.2 Add a test\n",
    ),
    ("openspec/changes/fix-ids/.openspec.yaml", "schema: spec-driven\n"),
    ("openspec/changes/fix-ids/specs/okf/documents/spec.md", delta_text),
    (
      "openspec/changes/archive/2026-01-01-first/proposal.md", "## Why\n\nFirst.\n",
    ),
    (
      "openspec/changes/archive/2026-01-01-first/specs/okf/documents/spec.md", "## ADDED Requirements\n\n### Requirement: X\nIt SHALL work.\n\n#### Scenario: Y\n- **WHEN** a\n- **THEN** b\n",
    ),
  ])
}

///|
fn profiles() -> Array[&@okf.Profile] {
  [@openspec.OpenSpecProfile::{ }]
}

///|
fn tree_bundle() -> @okf.Bundle raise {
  @okf.load_bundle(tree(), root=["openspec"], profiles=profiles())
}

///|
test "paths classify into OpenSpec kinds" {
  let k = (p : String) => @openspec.classify(@okf.BundlePath(p))
  assert_eq(
    k("/specs/okf/documents/spec.md"),
    Some(SpecFile(capability="okf/documents")),
  )
  assert_eq(
    k("/changes/a/proposal.md"),
    Some(ProposalFile(change="a", archived=false)),
  )
  assert_eq(
    k("/changes/archive/2026-x/design.md"),
    Some(DesignFile(change="2026-x", archived=true)),
  )
  assert_eq(
    k("/changes/a/specs/okf/documents/spec.md"),
    Some(DeltaFile(change="a", archived=false, capability="okf/documents")),
  )
  assert_eq(k("/project.md"), None)
}

///|
test "a tree loads as a bundle with derived types" {
  let b = tree_bundle()
  let types = b
    .concepts()
    .map(d => (d.path().to_string(), d.concept_type().unwrap_or("")))
  assert_eq(types, [
    ("/changes/archive/2026-01-01-first/proposal.md", "Change"),
    (
      "/changes/archive/2026-01-01-first/specs/okf/documents/spec.md", "Spec Delta",
    ),
    ("/changes/fix-ids/proposal.md", "Change"),
    ("/changes/fix-ids/specs/okf/documents/spec.md", "Spec Delta"),
    ("/changes/fix-ids/tasks.md", "Tasks"),
    ("/specs/okf/documents/spec.md", "Specification"),
  ])
  guard b.document(
      @okf.BundlePath("/changes/archive/2026-01-01-first/proposal.md"),
    )
    is Some(archived) else {
    fail("no archived change")
  }
  assert_eq(archived.metadata().text("state"), Some("archived"))
}

///|
test "requirements, scenarios, deltas and tasks parse" {
  let v = @openspec.view(tree_bundle())
  let spec = v.specs[0]
  assert_eq(spec.capability, "okf/documents")
  assert_eq(spec.purpose, Some("Read OKF bundles into immutable values."))
  let r = spec.requirements[0]
  assert_eq(r.name, "Concept IDs")
  assert_eq(r.text, "The library SHALL give each concept a Concept ID.")
  assert_eq(r.scenarios[0].name, "Concept ID from path")
  assert_eq(r.scenarios[0].when_, ["a bundle holds `/tables/customers.md`"])
  assert_eq(r.scenarios[0].then_, [
    "the concept has the Concept ID `tables/customers`", "the ID compares equal to the same path",
  ])
  guard v.changes.search_by(c => c.name == "fix-ids") is Some(i) else {
    fail("no change")
  }
  let change = v.changes[i]
  assert_eq(change.archived, false)
  assert_eq(change.deltas[0].deltas.map(d => d.op), [Modified, Renamed])
  assert_eq(change.deltas[0].deltas[1].renames, [("Old name", "New name")])
  assert_eq(change.task_groups[0].tasks.map(t => (t.number, t.done)), [
    ("1.1", true),
    ("1.2", false),
  ])
}

///|
test "changes link to their capabilities, so specs have backlinks" {
  let b = tree_bundle()
  let k = @okf.Knowledge([b])
  let g = @okf.Graph::build(k, profiles=profiles())
  let spec : @okf.DocKey = {
    bundle: "openspec",
    path: @okf.BundlePath("/specs/okf/documents/spec.md"),
  }
  let from = g.linked_from(spec).map(key => key.path.to_string())
  assert_true(from.contains("/changes/fix-ids/proposal.md"))
  assert_true(from.contains("/changes/archive/2026-01-01-first/proposal.md"))
  let change : @okf.DocKey = {
    bundle: "openspec",
    path: @okf.BundlePath("/changes/fix-ids/proposal.md"),
  }
  let targets = g.outbound(change).map(e => e.link.destination)
  assert_true(targets.contains("/changes/fix-ids/tasks.md"))
}

///|
fn findings(set : @okf.DocumentSet) -> Array[String] {
  let b = @okf.load_bundle(set, root=["openspec"], profiles=profiles())
  let report = @okf.validate(
    @okf.Knowledge([b]),
    [],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
    profiles=profiles(),
  )
  report.findings().map(f => f.rule).iter().collect()
}

///|
test "the OpenSpec checks pass on a valid tree" {
  assert_eq(findings(tree()), [])
}

///|
test "the OpenSpec checks find each problem" {
  let bad = tree()
    .with_entry({
      path: @okf.StorePath("openspec/changes/bad/specs/okf/documents/spec.md"),
      content: Text(
        "## MODIFIED Requirements\n\n### Requirement: Missing\nIt works.\n\n### Scenario: Wrong level\n- **WHEN** a\n- **THEN** b\n",
      ),
    })
    .with_entry({
      path: @okf.StorePath("openspec/changes/bad/specs/nothing/spec.md"),
      content: Text(
        "## REMOVED Requirements\n\n### Requirement: Gone\nIt SHALL go.\n\n#### Scenario: Z\n- **WHEN** a\n- **THEN** b\n",
      ),
    })
  let rules = findings(bad)
  assert_true(rules.contains("openspec-requirement-no-scenario"))
  assert_true(rules.contains("openspec-requirement-no-shall"))
  assert_true(rules.contains("openspec-scenario-heading"))
  assert_true(rules.contains("openspec-modified-unknown"))
  assert_true(rules.contains("openspec-delta-unknown-capability"))
}

///|
test "import creates native concepts, an index and a log" {
  let plan = @openspec.import_openspec(
    tree(),
    ["openspec"],
    ["kb"],
    "2026-10-23",
  )
  let paths = plan.changes().map(c => c.path().to_string()).iter().collect()
  assert_true(paths.contains("kb/specs/okf/documents/spec.md"))
  assert_true(paths.contains("kb/changes/fix-ids/proposal.md"))
  assert_true(paths.contains("kb/changes/fix-ids/.openspec.yaml"))
  assert_true(paths.contains("kb/index.md"))
  assert_true(paths.contains("kb/log.md"))
  let set = plan.apply_to(@okf.DocumentSet([]))
  guard set.get(@okf.StorePath("kb/index.md")) is Some(index) else {
    fail("no index")
  }
  assert_true(
    index.content.text().has_prefix("---\nokf_version: \"0.2\"\n---\n"),
  )
  let native = @okf.discover(set)
  assert_eq(native.bundles().length(), 1)
  let report = @okf.validate(
    native,
    [@okf.okf_v02_conformance()],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
  )
  assert_eq(report.count(Error), 0)
}

///|
test "native and tree forms give the same view, and the round trip keeps every file" {
  let original = tree()
  let imported = @openspec.import_openspec(
    original,
    ["openspec"],
    ["kb"],
    "2026-10-23",
  ).apply_to(@okf.DocumentSet([]))
  let native = @okf.load_bundle(imported, root=["kb"])
  let tree_view = @openspec.view(tree_bundle())
  assert_eq(@openspec.view(native).without_lines(), tree_view.without_lines())
  let exported = @openspec.export_openspec(imported, ["kb"], ["openspec"]).apply_to(
    @okf.DocumentSet([]),
  )
  assert_eq(
    exported.entries().map(e => (e.path.to_string(), e.content.text())),
    original.entries().map(e => (e.path.to_string(), e.content.text())),
  )
}

///|
test "export merges native Requirement and Scenario concepts" {
  let set = @okf.DocumentSet::of_texts([
    ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    (
      "kb/specs/a.md", "---\ntype: Specification\ncapability: a\n---\n# a Specification\n\n## Purpose\n\nA thing.\n",
    ),
    (
      "kb/reqs/r1.md", "---\ntype: Requirement\ncapability: a\nrequirement: Works\norder: 1\n---\nIt SHALL work.\n",
    ),
    (
      "kb/reqs/s1.md", "---\ntype: Scenario\ncapability: a\nrequirement: Works\nscenario: Simple\n---\n- **WHEN** used\n- **THEN** it works\n",
    ),
  ])
  let native = @okf.load_bundle(set, root=["kb"])
  let v = @openspec.view(native)
  assert_eq(v.specs[0].requirements.map(r => (r.name, r.scenarios.length())), [
    ("Works", 1),
  ])
  let out = @openspec.export_openspec(set, ["kb"], []).apply_to(
    @okf.DocumentSet([]),
  )
  guard out.get(@okf.StorePath("specs/a/spec.md")) is Some(spec) else {
    fail("no spec")
  }
  assert_eq(
    spec.content.text(),
    "# a Specification\n\n## Purpose\n\nA thing.\n\n## Requirements\n\n### Requirement: Works\nIt SHALL work.\n\n#### Scenario: Simple\n- **WHEN** used\n- **THEN** it works\n",
  )
}

///|
test "import and export keep binary assets byte for byte" {
  let png = b"\x89PNG\r\n\x1a\n\x00\xfe\xff"
  let original = tree().with_entry({
    path: @okf.StorePath("openspec/changes/fix-ids/diagram.png"),
    content: Bytes(png),
  })
  let imported = @openspec.import_openspec(
    original,
    ["openspec"],
    ["kb"],
    "2026-10-23",
  ).apply_to(@okf.DocumentSet([]))
  assert_eq(
    imported
    .get(@okf.StorePath("kb/changes/fix-ids/diagram.png"))
    .map(e => e.content),
    Some(Bytes(png)),
  )
  let exported = @openspec.export_openspec(imported, ["kb"], ["openspec"]).apply_to(
    @okf.DocumentSet([]),
  )
  assert_eq(
    exported
    .get(@okf.StorePath("openspec/changes/fix-ids/diagram.png"))
    .map(e => e.content),
    Some(Bytes(png)),
  )
}
