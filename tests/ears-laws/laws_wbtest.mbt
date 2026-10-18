///|
/// Shrink generation choices, then render again, preserving valid EARS syntax.
priv struct RequirementCase {
  feature : Bool
  states : ReadOnlyArray[UInt32]
  trigger : UInt32
  style : UInt32
} derive(Debug)

///|
impl @quickcheck.Arbitrary for RequirementCase with fn arbitrary(size, state) {
  let (feature, states, trigger, style) : (
    Bool,
    ReadOnlyArray[UInt32],
    UInt32,
    UInt32,
  ) = @quickcheck.Arbitrary::arbitrary(size, state)
  { feature, states, trigger, style, }
}

///|
impl @shrink.Shrink for RequirementCase with fn shrink(self) {
  @shrink.Shrink::shrink((self.feature, self.states, self.trigger, self.style)).map(parts => {
      let (feature, states, trigger, style) = parts
      { feature, states, trigger, style, }
    },
  )
}

///|
fn RequirementCase::system(self : RequirementCase) -> String {
  ["sensor", "Café controller", "🌙 monitor", "温度計"][(self.style % 4).reinterpret_as_int()]
}

///|
fn RequirementCase::preconditions(
  self : RequirementCase,
) -> ReadOnlyArray[String] {
  self.states.map(value => "state \{value} is active")
}

///|
fn RequirementCase::source(self : RequirementCase) -> String {
  let clauses = []
  if self.feature {
    clauses.push("WHERE logging is fitted")
  }
  for state in self.preconditions() {
    clauses.push("WHILE " + state)
  }
  match self.trigger % 3 {
    1 => clauses.push("WHEN polled")
    2 => clauses.push("IF disconnected")
    _ => ()
  }
  let prefix = if self.trigger % 3 == 2 { "THEN THE " } else { "THE " }
  clauses.push(
    prefix + self.system() + " SHALL report v1.2, status and temperature.",
  )
  clauses.join(", ")
}

///|
fn RequirementCase::newline(self : RequirementCase) -> String {
  match self.style % 3 {
    0 => "\n"
    1 => "\r\n"
    _ => "\r"
  }
}

///|
test "law: parsing generated syntax preserves each independent clause" {
  @expect.for_all(
    (input : RequirementCase) => {
      let requirement = @ears.parse(input.source())
      let feature = if input.feature { Some("logging is fitted") } else { None }
      let trigger = match input.trigger % 3 {
        1 => Some(@ears.Event("polled"))
        2 => Some(@ears.Unwanted("disconnected"))
        _ => None
      }
      @expect.expect_all(s => {
        s.expect(requirement.feature()).to_equal(feature)
        s.expect(requirement.preconditions()).to_equal(input.preconditions())
        s.expect(requirement.trigger()).to_equal(trigger)
        s.expect(requirement.system()).to_equal(input.system())
        s
        .expect(requirement.response())
        .to_equal("report v1.2, status and temperature.")
      })
    },
    count=200,
    max_size=12,
    max_shrinks=200,
    seed=2101,
  )
}

///|
test "law: canonical rendering round-trips and whitespace changes preserve meaning" {
  @expect.for_all(
    (input : RequirementCase) => {
      let requirement = @ears.parse(input.source())
      let canonical = requirement.to_string()
      let spaced = " \t" + input.source().replace(old=" ", new="\t\r\n ") + "\r"
      @expect.expect_all(s => {
        s.expect(@ears.parse(canonical)).to_equal(requirement)
        s.expect(@ears.parse(spaced)).to_equal(requirement)
        s.expect(@ears.parse(canonical).to_string()).to_equal(canonical)
      })
    },
    count=200,
    max_size=12,
    max_shrinks=200,
    seed=2102,
  )
}

///|
test "law: text and Markdown extraction agree and spans recover the original sentence" {
  @expect.for_all(
    (input : RequirementCase) => {
      let sentence = input.source()
      let expected = @ears.parse(sentence)
      let nl = input.newline()
      let text = "\u{FEFF}\t" + sentence + nl + "invalid" + nl + sentence
      let with_header = input.style % 2 == 0
      let prefix = if with_header {
        "\u{FEFF}---\{nl}title: '🌙 Café'\{nl}---\{nl}# Requirements\{nl}\{nl}- "
      } else {
        "\u{FEFF}- "
      }
      let source = prefix + sentence + nl
      let plain = @ears.parse_text(text)
      let markdown = @ears.parse_markdown(source)
      @expect.expect_all(s => {
        s.expect(plain.requirements().length()).to_equal(2)
        s.expect(plain.diagnostics().length()).to_equal(1)
        s.expect(markdown.requirements().length()).to_equal(1)
        s.expect(markdown.diagnostics().length()).to_equal(0)
      })
      guard markdown.requirements().get(0) is Some(item) else {
        fail("missing Markdown requirement")
      }
      guard item.origin() is Markdown(span=Some(span), ..) else {
        fail("no span")
      }
      @expect.expect_all(s => {
        s.expect(item.requirement()).to_equal(expected)
        s.expect(span.start()).to_equal(prefix.length())
        s.expect(span.line()).to_equal(if with_header { 6 } else { 1 })
        s.expect(span.column()).to_equal(if with_header { 3 } else { 4 })
        s.expect(source[span.start():span.end()].to_owned()).to_equal(sentence)
        s.expect(plain.requirements()[0].requirement()).to_equal(expected)
        s.expect(plain.requirements()[1].requirement()).to_equal(expected)
      })
    },
    count=200,
    max_size=12,
    max_shrinks=200,
    seed=2103,
  )
}
