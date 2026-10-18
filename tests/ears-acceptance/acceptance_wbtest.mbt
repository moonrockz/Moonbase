///|
enum Input {
  Text(String)
  Markdown(String)
  Mdc(String)
}

///|
enum CaseState {
  AwaitingSource
  Source(Input)
  Parsed(@ears.Specification)
}

///|
struct EarsWorld {
  mut state : CaseState
}

///|
fn EarsWorld::EarsWorld() -> EarsWorld {
  { state: AwaitingSource, }
}

///|
fn EarsWorld::parsed(self : EarsWorld) -> @ears.Specification raise {
  guard self.state is Parsed(spec) else { fail("parse a source first") }
  spec
}

///|
fn pattern_name(pattern : @ears.Pattern) -> String {
  match pattern {
    Ubiquitous => "ubiquitous"
    StateDriven => "state driven"
    EventDriven => "event driven"
    OptionalFeature => "optional feature"
    UnwantedBehaviour => "unwanted behaviour"
    Complex => "complex"
  }
}

///|
impl @moonspec.World for EarsWorld with fn configure(self, setup) {
  setup.given1("the plain EARS source:", (source : @moonspec.DocString) => {
    self.state = Source(Text(source.content))
  })
  setup.given1("the Markdown EARS source:", (source : @moonspec.DocString) => {
    self.state = Source(Markdown(source.content))
  })
  setup.given1("the existing MDC source:", (source : @moonspec.DocString) => {
    self.state = Source(Mdc(source.content))
  })
  setup.when0("the EARS specification is parsed", () => {
    guard self.state is Source(input) else { fail("no source") }
    self.state = Parsed(
      match input {
        Text(source) => @ears.parse_text(source)
        Markdown(source) => @ears.parse_markdown(source)
        Mdc(source) => @ears.from_mdc(@mdc.Document::Document(source))
      },
    )
  })
  setup.then2("there are {int} requirements and {int} diagnostics", (
    requirements : Int32,
    diagnostics : Int32,
  ) => {
    let spec = self.parsed()
    @expect.expect_all(s => {
      s.expect(spec.requirements().length()).to_equal(requirements)
      s.expect(spec.diagnostics().length()).to_equal(diagnostics)
    })
  })
  setup.then1("the first requirement is {string}", (expected : String) => {
    let spec = self.parsed()
    guard spec.requirements().get(0) is Some(item) else {
      fail("no first requirement")
    }
    @expect.expect(pattern_name(item.requirement().pattern())).to_equal(
      expected,
    )
  })
  setup.then2("the first requirement names {string} and requires {string}", (
    system : String,
    response : String,
  ) => {
    let spec = self.parsed()
    guard spec.requirements().get(0) is Some(item) else {
      fail("no first requirement")
    }
    @expect.expect_all(s => {
      s.expect(item.requirement().system()).to_equal(system)
      s.expect(item.requirement().response()).to_equal(response)
    })
  })
  setup.then0("the diagnostic reports a missing SHALL", () => {
    let spec = self.parsed()
    guard spec.diagnostics().get(0) is Some(diagnostic) else {
      fail("no diagnostic")
    }
    @expect.expect(diagnostic.error()).to_equal(@ears.MissingShall)
  })
  setup.then1("the YAML payload remains {string}", (expected : String) => {
    guard self.parsed().document() is Some(doc) else { fail("no document") }
    guard doc.frontmatter() is Some(header) else { fail("no frontmatter") }
    @expect.expect(header.raw().trim().to_owned()).to_equal(expected)
  })
  setup.then1("the first requirement starts on original line {int}", (
    expected : Int32,
  ) => {
    let spec = self.parsed()
    guard spec.requirements().get(0) is Some(item) else {
      fail("no requirement")
    }
    guard item.origin() is Markdown(path~, span=Some(span)) else {
      fail("no Markdown position")
    }
    guard spec.document() is Some(doc) else { fail("no document") }
    @expect.expect_all(s => {
      s.expect(span.line()).to_equal(expected)
      s.expect(doc.root().at(path) is Some(Block(_))).to_be_true()
    })
  })
}

///|
async test "EARS acceptance scenarios" {
  @moonspec.run_or_fail(
    () => EarsWorld::EarsWorld(),
    @moonspec.RunOptions::RunOptions([
      @moonspec.FeatureSource::File("ears-acceptance/features/ears.feature"),
    ]),
  )
}
