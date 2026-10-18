///|
test "all basic patterns and complex clauses expose their structure" {
  let cases : Array[(String, @ears.Pattern)] = [
    ("The sensor shall measure temperature.", Ubiquitous),
    ("While enabled, the sensor shall measure temperature.", StateDriven),
    ("When polled, the sensor shall measure temperature.", EventDriven),
    ("Where fitted, the sensor shall measure temperature.", OptionalFeature),
    (
      "If disconnected, then the sensor shall report a fault.",
      UnwantedBehaviour,
    ),
    (
      "While enabled, when polled, the sensor shall measure temperature.",
      Complex,
    ),
  ]
  for (source, pattern) in cases {
    let requirement = @ears.Requirement::Requirement(source)
    @expect.expect_all(s => {
      s.expect(requirement.pattern(), label=source).to_equal(pattern)
      s.expect(requirement.system()).to_equal("sensor")
      s.expect(@ears.parse(requirement.to_string())).to_equal(requirement)
    })
  }
  let requirement = @ears.parse(
    "Where fitted, while enabled, while powered, if disconnected then the sensor shall report a fault.",
  )
  @expect.expect_all(s => {
    s.expect(requirement.pattern()).to_equal(@ears.Complex)
    s.expect(requirement.feature()).to_equal(Some("fitted"))
    s.expect(requirement.preconditions()).to_equal(["enabled", "powered"])
    s
    .expect(requirement.trigger())
    .to_equal(Some(@ears.Unwanted("disconnected")))
    s.expect(requirement.response()).to_equal("report a fault.")
  })
}

///|
test "whitespace and keyword case normalize without changing natural-language case" {
  let requirement = @ears.parse(
    " \tWHILE Ready,\r\n WHEN Café 🌙 is polled, THE Sensor shall\treturn v1.2. ",
  )
  @expect.expect_all(s => {
    s.expect(requirement.preconditions()).to_equal(["Ready"])
    s
    .expect(requirement.trigger())
    .to_equal(Some(@ears.Event("Café 🌙 is polled")))
    s
    .expect(requirement.to_string())
    .to_equal(
      "While Ready, When Café 🌙 is polled, the Sensor shall return v1.2.",
    )
  })
}

///|
test "ordinary commas stay in clauses and responses" {
  let requirement = @ears.parse(
    "When red, green or blue is selected, the lamp shall blink, beep and stop.",
  )
  @expect.expect_all(s => {
    s
    .expect(requirement.trigger())
    .to_equal(Some(@ears.Event("red, green or blue is selected")))
    s.expect(requirement.response()).to_equal("blink, beep and stop.")
  })
}

///|
test "THEN inside unwanted conditions does not end a clause" {
  let conditions = [
    "a scan completes then retries", "a scan completes, then retries", "a scan completes THEN retries then pauses",
  ]
  for condition in conditions {
    for separator in [" then ", ", then "] {
      let requirement = @ears.parse(
        "If " + condition + separator + "the scanner shall stop.",
      )
      @expect.expect_all(s => {
        s
        .expect(requirement.trigger())
        .to_equal(Some(@ears.Unwanted(condition)))
        s.expect(requirement.system()).to_equal("scanner")
        s.expect(@ears.parse(requirement.to_string())).to_equal(requirement)
      })
    }
  }
}

///|
test "Markdown columns include a first-line BOM only on the first line" {
  let cases : Array[(String, Int32, Int32)] = [
    ("\u{FEFF}The gauge shall reset.", 1, 2),
    ("\u{FEFF}- The gauge shall reset.", 1, 4),
    ("\u{FEFF}\nThe gauge shall reset.", 2, 1),
    ("\u{FEFF}---\ntitle: Gauge\n---\nThe gauge shall reset.", 4, 1),
  ]
  for (source, line, column) in cases {
    let spec = @ears.parse_markdown(source)
    guard spec.requirements().get(0) is Some(item) else {
      fail("missing requirement")
    }
    guard item.origin() is Markdown(span=Some(span), ..) else {
      fail("missing span")
    }
    @expect.expect_all(s => {
      s.expect(span.line()).to_equal(line)
      s.expect(span.column()).to_equal(column)
      s
      .expect(source[span.start():span.end()].to_owned())
      .to_equal("The gauge shall reset.")
    })
  }
}

///|
fn rejection(source : String) -> @ears.ParseError raise {
  let _ = @ears.parse(source) catch { error => return error }
  fail("expected rejection: " + source)
}

///|
test "malformed requirements report typed errors" {
  let cases : Array[(String, @ears.ParseError)] = [
    (" \n", @ears.EmptyRequirement),
    ("A sensor shall measure.", @ears.ExpectedSystem),
    ("The shall measure.", @ears.ExpectedSystem),
    ("The sensor should measure.", @ears.MissingShall),
    ("The sensor shall", @ears.MissingResponse),
    ("The sensor shall .", @ears.MissingResponse),
    ("When , the sensor shall measure.", @ears.EmptyClause(keyword="when")),
    ("While , the sensor shall measure.", @ears.EmptyClause(keyword="while")),
    ("Where , the sensor shall measure.", @ears.EmptyClause(keyword="where")),
    ("If , then the sensor shall measure.", @ears.EmptyClause(keyword="if")),
    ("When polled the sensor shall measure.", @ears.MissingSeparator),
    ("If disconnected, the sensor shall stop.", @ears.MissingThen),
    ("If disconnected then a sensor shall stop.", @ears.ExpectedSystem),
    (
      "While enabled, where fitted, the sensor shall measure.",
      @ears.InvalidClauseOrder,
    ),
    (
      "When polled, while enabled, the sensor shall measure.",
      @ears.InvalidClauseOrder,
    ),
    (
      "When polled, when polled again, the sensor shall measure.",
      @ears.InvalidClauseOrder,
    ),
    (
      "Where fitted, where powered, the sensor shall measure.",
      @ears.InvalidClauseOrder,
    ),
  ]
  for (source, expected) in cases {
    @expect.expect(rejection(source), label=source).to_equal(expected)
  }
}

///|
test "plain text preserves valid siblings and exact line spans" {
  let source = "\u{FEFF}  The 🌙 sensor shall measure. \r\n\rWhen polled, the sensor shall reply.\ninvalid\rThe sensor shall stop."
  let spec = @ears.parse_text(source)
  @expect.expect_all(s => {
    s.expect(spec.requirements().length()).to_equal(3)
    s.expect(spec.diagnostics().length()).to_equal(1)
    s.expect(spec.document()).to_be_none()
    s.expect(spec.diagnostics()[0].error()).to_equal(@ears.ExpectedSystem)
    s.expect(spec.diagnostics()[0].text()).to_equal("invalid")
  })
  let first = spec.requirements()[0]
  guard first.origin() is Text(span) else { fail("not a text origin") }
  @expect.expect_all(s => {
    s
    .expect(source[span.start():span.end()].to_owned())
    .to_equal(first.requirement().to_string())
    s.expect(span.start()).to_equal(3)
    s.expect(span.line()).to_equal(1)
    s.expect(span.column()).to_equal(4)
  })
  guard spec.diagnostics()[0].origin() is Text(span) else {
    fail("not a text origin")
  }
  @expect.expect(span.line()).to_equal(4)
}

///|
test "Markdown extraction retains metadata, positions and paths" {
  let source = "---\r\ntitle: Requirements 🌙\r\n---\r\n# Requirements\r\n\r\n- When **polled**, the sensor shall\r\n  return `READY`.\r\n\r\n> The sensor shall stop.\r\n\r\nThe sensor should reset.\r\n"
  let spec = @ears.parse_markdown(source, file="sensor.mdc")
  @expect.expect_all(s => {
    s.expect(spec.requirements().length()).to_equal(2)
    s.expect(spec.diagnostics().length()).to_equal(1)
    s
    .expect(spec.requirements()[0].requirement().to_string())
    .to_equal("When polled, the sensor shall return READY.")
    s.expect(spec.diagnostics()[0].error()).to_equal(@ears.MissingShall)
  })
  guard spec.document() is Some(doc) else { fail("no retained document") }
  guard doc.frontmatter() is Some(header) else { fail("no metadata") }
  @expect.expect(header.raw()).to_equal("title: Requirements 🌙\r\n")
  guard spec.requirements()[0].origin() is Markdown(path~, span=Some(span)) else {
    fail("no Markdown origin")
  }
  @expect.expect_all(s => {
    s.expect(span.line()).to_equal(6)
    s.expect(span.column()).to_equal(3)
    s
    .expect(source[span.start():span.end()].to_owned())
    .to_equal("When **polled**, the sensor shall\r\n  return `READY`.")
    s.expect(doc.root().at(path) is Some(Block(_))).to_be_true()
  })
}

///|
test "Markdown ignores prose, headings, code, HTML, images, tables and footnotes" {
  let source = "# The sensor shall be a heading.\n\nThe document describes requirements.\n\n```text\nThe sensor shall be a code sample.\n```\n\n    The sensor shall be indented code.\n\n<div>\nThe sensor shall be HTML.\n</div>\n\n![The sensor shall be alt text.](image.png)\n\n| requirements |\n| --- |\n| The sensor shall be a table sample. |\n\n[^note]: The sensor shall be a footnote.\n\nThe **sensor** shall [return READY](https://example.com).\n"
  let spec = @ears.parse_markdown(source, strict=false)
  @expect.expect_all(s => {
    s.expect(spec.requirements().length()).to_equal(1)
    s.expect(spec.diagnostics().length()).to_equal(0)
    s
    .expect(spec.requirements()[0].requirement().to_string())
    .to_equal("The sensor shall return READY.")
  })
}

///|
test "an existing MDC document without locations still yields resolvable origins" {
  let doc = @mdc.Document::Document(
    "The sensor shall stop.",
    locs=false,
    layout=false,
  )
  let spec = @ears.from_mdc(doc)
  @expect.expect(spec.requirements().length()).to_equal(1)
  guard spec.requirements()[0].origin() is Markdown(path~, span~) else {
    fail("not Markdown")
  }
  @expect.expect_all(s => {
    s.expect(span).to_be_none()
    s.expect(doc.root().at(path) is Some(Block(_))).to_be_true()
  })
}

///|
test "inline autolinks and math retain their text in responses" {
  let spec = @ears.parse_markdown(
    "The sensor shall publish <https://example.com/status> and report $x + y$.\n",
    strict=false,
  )
  @expect.expect_all(s => {
    s.expect(spec.requirements().length()).to_equal(1)
    s.expect(spec.diagnostics().length()).to_equal(0)
  })
  @expect.expect(spec.requirements()[0].requirement().response()).to_equal(
    "publish https://example.com/status and report x + y.",
  )
}

///|
test "empty specifications and keyword prefixes create no spurious requirements" {
  for source in ["", "\u{FEFF}", " \t\r\n\r\n"] {
    let spec = @ears.parse_text(source)
    @expect.expect_all(s => {
      s.expect(spec.requirements().length()).to_equal(0)
      s.expect(spec.diagnostics().length()).to_equal(0)
    })
  }
  let spec = @ears.parse_markdown(
    "Whenever ready, a sensor responds.\n\nThe sensor shallower setting is described here.\n",
  )
  @expect.expect_all(s => {
    s.expect(spec.requirements().length()).to_equal(0)
    s.expect(spec.diagnostics().length()).to_equal(0)
  })
}

///|
test "invalid frontmatter propagates MDC errors" {
  let rejected = @ears.parse_markdown("---\ntitle: unclosed\n") catch {
    @mdc.UnterminatedFrontmatter => return
    _ => fail("wrong error")
  }
  ignore(rejected)
  fail("invalid frontmatter was accepted")
}
