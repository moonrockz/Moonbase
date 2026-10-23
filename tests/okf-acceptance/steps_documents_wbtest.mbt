///|
fn configure_documents(world : OkfWorld, setup : @moonspec.Setup) -> Unit {
  setup.then1("the documents are:", (table : @moonspec.DataTable) => {
    let b = world.only_bundle()
    let actual = b
      .documents()
      .map(d => [d.path().to_string(), kind_name(d.kind())])
      .iter()
      .collect()
    @expect.expect(actual).to_equal(table_rows(table, ["path", "kind"]))
  })
  setup.then1("the documents include {string}", (path : String) => {
    let b = world.only_bundle()
    @expect.expect(b.document(@okf.BundlePath(path)) is Some(_)).to_equal(true)
  })
  setup.then1("the assets are {string}", (list : String) => {
    let b = world.only_bundle()
    @expect.expect(b.assets().map(p => p.to_string()).iter().collect()).to_equal(
      items(list),
    )
  })
  setup.then2("the Concept ID of {string} is {string}", (
    path : String,
    id : String,
  ) => {
    let (_, d) = world.doc(path)
    @expect.expect(d.concept_id().map(c => c.to_string())).to_equal(Some(id))
  })
  setup.then1("the OKF version is {string}", (version : String) => {
    let b = match world.loaded().bundles().iter().collect() {
      [b, ..] => b
      [] => fail("no bundle")
    }
    @expect.expect(b.okf_version()).to_equal(Some(version))
  })
  setup.then2("the keys of {string} are {string}", (
    path : String,
    keys : String,
  ) => {
    let (_, d) = world.doc(path)
    @expect.expect(d.metadata().keys()).to_equal(items(keys))
  })
  setup.then3("the field {string} of {string} is {string}", (
    key : String,
    path : String,
    value : String,
  ) => {
    let (_, d) = world.doc(path)
    @expect.expect(d.metadata().text(key)).to_equal(Some(value))
  })
  setup.then2("the source ids of {string} are {string}", (
    path : String,
    ids : String,
  ) => {
    let (_, d) = world.doc(path)
    @expect.expect(d.metadata().sources().map(s => s.id.unwrap_or(""))).to_equal(
      items(ids),
    )
  })
  setup.then2("the trust tier of {string} is {string}", (
    path : String,
    tier : String,
  ) => {
    let (_, d) = world.doc(path)
    @expect.expect(tier_name(d.metadata().trust_tier())).to_equal(tier)
  })
  setup.then2("the display title of {string} is {string}", (
    path : String,
    title : String,
  ) => {
    let (_, d) = world.doc(path)
    @expect.expect(d.display_title()).to_equal(title)
  })
  setup.then2("{string} is stale at {string}", (path : String, at : String) => {
    let (b, d) = world.doc(path)
    let now = @okf.FixedClock::at(at).instant
    @expect.expect(d.metadata().is_stale(now, options=b.options())).to_equal(
      true,
    )
  })
  setup.then2("{string} is not stale at {string}", (path : String, at : String) => {
    let (b, d) = world.doc(path)
    let now = @okf.FixedClock::at(at).instant
    @expect.expect(d.metadata().is_stale(now, options=b.options())).to_equal(
      false,
    )
  })
  setup.then2("the effective status of {string} is {string}", (
    path : String,
    status : String,
  ) => {
    let (b, d) = world.doc(path)
    let actual = match d.metadata().effective_status(options=b.options()) {
      Some(s) => s.to_string()
      None => ""
    }
    @expect.expect(actual).to_equal(status)
  })
  setup.then1("{string} has a frontmatter error", (path : String) => {
    let (_, d) = world.doc(path)
    @expect.expect(d.metadata_error() is Some(_)).to_equal(true)
  })
  setup.then1("{string} has no frontmatter and no error", (path : String) => {
    let (_, d) = world.doc(path)
    @expect.expect((d.has_frontmatter_block(), d.metadata_error() is Some(_))).to_equal(
      (false, false),
    )
  })
  setup.then1("the bundles are:", (table : @moonspec.DataTable) => {
    let actual = world
      .loaded()
      .bundles()
      .map(b => [b.label(), b.group().join("/")])
      .iter()
      .collect()
    @expect.expect(actual).to_equal(table_rows(table, ["label", "group"]))
  })
  setup.then1("the strays are {string}", (list : String) => {
    @expect.expect(
      world.loaded().strays().map(p => p.to_string()).iter().collect(),
    ).to_equal(items(list))
  })
}
