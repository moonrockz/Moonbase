///|
fn unescape(text : String) -> String {
  text
  .replace_all(old="\\r", new="\r")
  .replace_all(old="\\n", new="\n")
  .replace_all(old="\\\"", new="\"")
}

///|
fn graph_of(world : OkfWorld) -> @okf.Graph raise {
  @okf.Graph::build(world.loaded(), profiles=world.profiles)
}

///|
fn configure_relationships(world : OkfWorld, setup : @moonspec.Setup) -> Unit {
  setup.then2("the links of {string} are:", (
    path : String,
    table : @moonspec.DataTable,
  ) => {
    let (_, d) = world.doc(path)
    let actual = d
      .links()
      .map(l => {
        [l.text, l.destination, l.line.to_string(), link_kind_name(l.kind)]
      })
    @expect.expect(actual).to_equal(
      table_rows(table, ["text", "destination", "line", "kind"]),
    )
  })
  setup.then2("the backlinks of {string} are {string}", (
    path : String,
    list : String,
  ) => {
    let keys = graph_of(world)
      .linked_from(world.key(path))
      .map(k => k.path.to_string())
    @expect.expect(keys).to_equal(items(list))
  })
  setup.then1("the broken links are {string}", (list : String) => {
    let actual = graph_of(world)
      .broken()
      .map(e => e.from.path.to_string() + " -> " + e.link.destination)
    actual.sort_by(@okf.lexical_compare)
    @expect.expect(actual).to_equal(items(list))
  })
  setup.then2("the link from {string} to {string} escapes the bundle", (
    from : String,
    dest : String,
  ) => {
    let key = world.key(from)
    let edge = graph_of(world)
      .outbound(key)
      .iter()
      .find_first(e => e.link.destination == dest)
    @expect.expect(edge.map(e => e.escapes)).to_equal(Some(true))
  })
  setup.then1("the orphans are {string}", (list : String) => {
    let k = world.loaded()
    let actual = graph_of(world).orphans(k).map(key => key.path.to_string())
    @expect.expect(actual).to_equal(items(list))
  })
}

///|
fn configure_indexes(world : OkfWorld, setup : @moonspec.Setup) -> Unit {
  setup.then2("the index entries of {string} are:", (
    path : String,
    table : @moonspec.DataTable,
  ) => {
    let (_, d) = world.doc(path)
    let actual = d
      .index_model()
      .entries()
      .map(e => [e.text, e.destination, e.description.unwrap_or("")])
    @expect.expect(actual).to_equal(
      table_rows(table, ["text", "destination", "description"]),
    )
  })
  setup.then1("the unindexed concepts are {string}", (list : String) => {
    let actual = world
      .only_bundle()
      .unindexed_concepts()
      .map(d => d.path().to_string())
    @expect.expect(actual).to_equal(items(list))
  })
  setup.then1("drift is reported only for {string}", (path : String) => {
    let actual = world
      .only_bundle()
      .description_drift()
      .map(d => d.concept.path().to_string())
    @expect.expect(actual).to_equal([path])
  })
  setup.then2("the log of {string} has the dates {string}", (
    path : String,
    dates : String,
  ) => {
    let (_, d) = world.doc(path)
    @expect.expect(d.log_model().sections.map(s => s.date)).to_equal(
      items(dates),
    )
  })
  setup.then1("the log of {string} is not newest first", (path : String) => {
    let (_, d) = world.doc(path)
    @expect.expect(d.log_model().order_problem() is Some(_)).to_equal(true)
  })
  setup.then2("the generated index of {string} is:", (
    dir : String,
    expected : @moonspec.DocString,
  ) => {
    let text = @okf.generate_index(
      world.only_bundle(),
      dir=items(dir.replace_all(old="/", new=",")),
    )
    @expect.expect(text).to_equal(expected.content)
  })
  setup.then1("the lookup of {string} finds nothing", (path : String) => {
    @expect.expect(world.loaded().find_document(path) is NotFound).to_equal(
      true,
    )
  })
  setup.then2("the lookup of {string} finds {string}", (
    path : String,
    found : String,
  ) => {
    let actual = match world.loaded().find_document(path) {
      Found((_, d)) => d.path().to_string()
      _ => ""
    }
    @expect.expect(actual).to_equal(found)
  })
  setup.then3("the concepts with type {string} and tag {string} are {string}", (
    t : String,
    tag : String,
    list : String,
  ) => {
    let actual = world
      .loaded()
      .filter([TypeIs(t), HasTag(tag)])
      .map(p => p.1.path().to_string())
    @expect.expect(actual).to_equal(items(list))
  })
  setup.then2("the facet {string} is {string}", (key : String, list : String) => {
    let actual = world.loaded().facet(key).map(p => p.0 + "=" + p.1.to_string())
    @expect.expect(actual).to_equal(items(list))
  })
  setup.then3(
    "the scan for {string} with bodies finds {string} on line {int}",
    (text : String, path : String, line : Int32) => {
      let hits = world.loaded().scan(text, bodies=true)
      let actual = hits.map(h => (h.key.path.to_string(), h.lines.map(l => l.0)))
      @expect.expect(actual).to_equal([(path, [line])])
    },
  )
  setup.then3("the search for {string} with limit {int} returns {string}", (
    query : String,
    limit : Int32,
    list : String,
  ) => {
    let hits = @okf.search_knowledge(
      world.loaded(),
      @okf.SearchRequest(query, limit~),
    )
    @expect.expect(hits.map(h => h.key.path.to_string())).to_equal(items(list))
  })
  setup.then2("the outline of {string} is {string}", (
    path : String,
    list : String,
  ) => {
    let (_, d) = world.doc(path)
    let actual = d.outline().map(h => "\{h.level}:\{h.text}:\{h.line}")
    @expect.expect(actual).to_equal(items(list))
  })
  setup.then3("the code of section {string} of {string} is {string}", (
    heading : String,
    path : String,
    code : String,
  ) => {
    let (_, d) = world.doc(path)
    guard d.section(heading) is Some(section) else {
      fail("no section \{heading}")
    }
    let actual = section.code_blocks.map(c => {
      c.language.unwrap_or("") + ": " + c.code
    })
    @expect.expect(actual).to_equal([code])
  })
}

///|
fn configure_validation(world : OkfWorld, setup : @moonspec.Setup) -> Unit {
  setup.given2("the rule {string} has the severity {string}", (
    rule : String,
    severity : String,
  ) => world.overrides.push((rule, severity_of(severity))))
  setup.given1("the rule {string} is turned off", (rule : String) => {
    world.disabled.push(rule)
  })
  setup.when1("the knowledge at {string} is validated", (root : String) => {
    let root = items(root.replace_all(old="/", new=","))
    let knowledge = @okf.Knowledge(
      [
        @okf.load_bundle(
          world.set(),
          root~,
          options=world.options,
          profiles=world.profiles,
        ),
      ],
      options=world.options,
    )
    world.knowledge = Some(knowledge)
    world.report = Some(
      @okf.validate(
        knowledge,
        [@okf.okf_v02_conformance(), @okf.advisory()],
        world.clock,
        config=@okf.ValidationConfig(
          overrides=world.overrides,
          disabled=world.disabled,
        ),
        profiles=world.profiles,
      ),
    )
  })
  setup.then0("there are no errors", () => {
    @expect.expect(world.validated().count(Error)).to_equal(0)
  })
  setup.then1("the findings are:", (table : @moonspec.DataTable) => {
    let actual = world
      .validated()
      .findings()
      .map(f => {
        [
          match f.severity {
            Error => "error"
            Warning => "warning"
            Info => "info"
          },
          f.rule,
          f.path,
        ]
      })
      .iter()
      .collect()
    @expect.expect(actual).to_equal(
      table_rows(table, ["severity", "rule", "path"]),
    )
  })
  setup.then1("the findings include {string}", (text : String) => {
    let parts = text.split(" ").map(s => s.to_owned()).collect()
    let found = world
      .validated()
      .findings()
      .iter()
      .any(f => {
        (match f.severity {
          Error => "error"
          Warning => "warning"
          Info => "info"
        }) ==
        parts[0] &&
        f.rule == parts[1] &&
        f.path == parts[2]
      })
    @expect.expect(found).to_equal(true)
  })
  setup.then0("the result fails", () => {
    @expect.expect(world.validated().fails()).to_equal(true)
  })
  setup.then0("the result passes", () => {
    @expect.expect(world.validated().fails()).to_equal(false)
  })
  setup.then0("the result fails in strict mode", () => {
    @expect.expect(world.validated().fails(strict=true)).to_equal(true)
  })
}

///|
fn configure_editing(world : OkfWorld, setup : @moonspec.Setup) -> Unit {
  setup.given1("the text {string}", (text : String) => {
    world.text = unescape(text)
  })
  setup.when2("the key {string} is set to {string}", (
    key : String,
    value : String,
  ) => {
    let r = @edit.set_key(world.text, key, value)
    world.text = r.text
    world.changed = r.changed
  })
  setup.then1("the text is {string}", (text : String) => {
    @expect.expect(world.text).to_equal(unescape(text))
  })
  setup.then0("the text changed", () => {
    @expect.expect(world.changed).to_equal(true)
  })
  setup.then0("the text did not change", () => {
    @expect.expect(world.changed).to_equal(false)
  })
  setup.when4(
    "the concept {string} of type {string} titled {string} is planned on {string}",
    (path : String, t : String, title : String, date : String) => {
      let bundle = world.only_bundle()
      world.plan = Some(
        @edit.plan_add_concept(bundle, path, t, title, title, date),
      ) catch {
        @edit.ReservedName(name) => {
          world.failure = Some("\{name} is a reserved name")
          None
        }
        e => {
          world.failure = Some(e.to_string())
          None
        }
      }
    },
  )
  setup.then1("the plan changes {string}", (list : String) => {
    guard world.plan is Some(plan) else { fail("no plan") }
    @expect.expect(
      plan.changes().map(c => c.path().to_string()).iter().collect(),
    ).to_equal(items(list))
  })
  setup.then0("nothing is written", () => {
    @expect.expect(world.set().length()).to_equal(world.files.length())
  })
  setup.then1("the plan is refused because {string}", (reason : String) => {
    @expect.expect(world.failure).to_equal(Some(reason))
  })
}
