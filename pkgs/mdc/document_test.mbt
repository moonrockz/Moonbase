///|
test "plain Markdown uses cmark without frontmatter" {
  let source = "# Intent\n\nA **goal** with [a link][ref].\n\n[ref]: https://example.com\n"
  let doc = @mdc.parse(source)
  assert_true(doc.frontmatter() is None)
  assert_eq(doc.body(), source)
  assert_eq(doc.body_offset(), 0)
  assert_eq(doc.body_line(), 1)
  assert_eq(doc.to_cmark().defs.length(), 1)
  let headings = doc.fold(
    [],
    @mdc.Folder::Folder((acc, node) => {
      if node is Block(view) && view.kind() is Heading(level~) {
        acc.push(level)
      }
      Continue(acc)
    }),
  )
  assert_eq(headings, [1])
}

///|
test "YAML mapping preserves nested values and the exact body" {
  let doc = @mdc.parse(
    "---\nname: intent\nactive: true\nsteps:\n  - title: Start\n---\n# Goal\n",
  )
  guard doc.frontmatter() is Some(frontmatter) else { fail("no frontmatter") }
  assert_eq(
    frontmatter.raw(),
    "name: intent\nactive: true\nsteps:\n  - title: Start\n",
  )
  assert_eq(frontmatter.value().to_json(), {
    "name": "intent",
    "active": true,
    "steps": [{ "title": "Start" }],
  })
  assert_eq(doc.body(), "# Goal\n")
  assert_eq(doc.body_line(), 7)
  assert_eq(doc.body_offset(), 58)
  let locations = doc.fold(
    [],
    @mdc.Folder::Folder((acc, node) => {
      if node is Block(view) && view.kind() is Heading(_) {
        acc.push((view.location().first_line.0, view.location().first_ccode))
      }
      Continue(acc)
    }),
  )
  assert_eq(locations, [(1, 0)])
}

///|
test "BOM, newline forms, trailing delimiter blanks and EOF" {
  for newline in ["\n", "\r\n", "\r"] {
    let source = "\u{FEFF}--- \t\{newline}title: '🌙'\{newline}...\t\{newline}body"
    let doc = @mdc.parse(source)
    assert_eq(doc.body(), "body")
    assert_eq(doc.body_line(), 4)
    assert_eq(doc.body_offset(), source.length() - 4)
  }
  let doc = @mdc.parse("---\n---")
  assert_eq(doc.body(), "")
  assert_eq(doc.body_line(), 2)
  guard doc.frontmatter() is Some(frontmatter) else { fail("no frontmatter") }
  assert_eq(frontmatter.value().to_json(), {})
  let plain = @mdc.parse("\u{FEFF}# Goal")
  assert_eq(plain.body_offset(), 1)
  assert_eq(plain.body(), "# Goal")
}

///|
test "only a complete first-line delimiter opens frontmatter" {
  for
    source in [
      "\n---\ntitle: value\n---\n", " ---\ntitle: value\n---\n", "----\n", "--- title\n",
      "```yaml\n---\n```\n", "title\n---\n",
    ] {
    let doc = @mdc.parse(source)
    assert_true(doc.frontmatter() is None)
    assert_eq(doc.body(), source)
  }
}

///|
test "unterminated frontmatter is an error" {
  for
    source in [
      "---", "---\n", "---\nname: intent\n", "---\nname: intent\n ---\n",
    ] {
    try {
      let _ = @mdc.parse(source)
      fail("accepted an unterminated header")
    } catch {
      @mdc.UnterminatedFrontmatter => ()
      _ => fail("wrong error")
    }
  }
}

///|
test "invalid YAML reports original source coordinates" {
  try {
    let _ = @mdc.parse("---\nname: ]\n---\nbody")
    fail("accepted invalid YAML")
  } catch {
    @mdc.InvalidFrontmatter(line~, column~, message~) => {
      assert_eq(line, 2)
      assert_eq(column, 7)
      assert_false(message.is_empty())
    }
    _ => fail("wrong error")
  }
}

///|
test "empty and comment-only payloads are empty mappings" {
  for payload in ["", " \t\n", "# comment\n"] {
    let doc = @mdc.parse("---\n\{payload}---\n")
    guard doc.frontmatter() is Some(frontmatter) else { fail("no frontmatter") }
    assert_eq(frontmatter.value().to_json(), {})
  }
}

///|
test "frontmatter must be a mapping" {
  for payload in ["text", "- a\n- b", "null", "42"] {
    try {
      let _ = @mdc.parse("---\n\{payload}\n---\n")
      fail("accepted non-mapping YAML")
    } catch {
      @mdc.InvalidFrontmatter(line=2, column=1, ..) => ()
      _ => fail("wrong error")
    }
  }
}

///|
test "cmark options pass through" {
  let doc = @mdc.parse("# Goal\n", file="intent.mdc", locs=true)
  assert_eq(doc.to_cmark().block.meta().loc.file, "intent.mdc")
  let doc = @mdc.parse("# Goal\n", locs=false)
  assert_true(doc.to_cmark().block.meta().loc.is_none())
}

///|
test "the Markdown body works with a cmark folder" {
  let doc = @mdc.parse("---\ntitle: Goal\n---\n# First\n\n## Second\n")
  let folder : @cmark.Folder[Int32] = @cmark.Folder::new(block=(_, acc, block) => {
    match block {
      Heading(_) => Fold(acc + 1)
      _ => Default
    }
  })
  assert_eq(folder.fold_doc(0, doc.to_cmark()), 2)
}
