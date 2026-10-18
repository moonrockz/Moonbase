///|
test "smart constructor derives YAML from the exact payload" {
  let raw = "# comment\r\nname: Goal\r\nsteps:\r\n  - title: Start\r\n"
  let frontmatter = @mdc.Frontmatter::Frontmatter(raw)
  assert_eq(frontmatter.raw(), raw)
  assert_eq(frontmatter.value().to_json(), {
    "name": "Goal",
    "steps": [{ "title": "Start" }],
  })
}

///|
test "mutating returned YAML cannot invalidate frontmatter" {
  let frontmatter = @mdc.Frontmatter::Frontmatter(
    "name: Goal\nsteps:\n  - title: Start\n",
  )
  guard frontmatter.value() is Map(fields) else { fail("not a mapping") }
  fields["name"] = @yaml.Yaml::String("Changed")
  guard fields.get("steps") is Some(Array(steps)) else { fail("no steps") }
  guard steps[0] is Map(step) else { fail("no step") }
  step["title"] = @yaml.Yaml::String("Changed")
  steps.push(@yaml.Yaml::Null)
  assert_eq(frontmatter.value().to_json(), {
    "name": "Goal",
    "steps": [{ "title": "Start" }],
  })
  assert_eq(
    frontmatter.value(),
    @mdc.Frontmatter::Frontmatter(frontmatter.raw()).value(),
  )
}

///|
test "smart constructor accepts empty and comment-only payloads" {
  for raw in ["", " \t\n", "# comment\n"] {
    let frontmatter = @mdc.Frontmatter::Frontmatter(raw)
    assert_eq(frontmatter.raw(), raw)
    assert_eq(frontmatter.value().to_json(), {})
  }
}

///|
test "smart constructor rejects non-mappings and multiple YAML documents" {
  for raw in ["text", "- a\n- b", "null", "42", "a: 1\n---\nb: 2\n"] {
    try {
      let _ = @mdc.Frontmatter::Frontmatter(raw)
      fail("accepted an invalid payload")
    } catch {
      @mdc.InvalidFrontmatter(line=1, column=1, ..) => ()
      _ => fail("wrong error")
    }
  }
}

///|
test "smart constructor reports positions within its payload" {
  try {
    let _ = @mdc.Frontmatter::Frontmatter("name: Goal\nsteps: ]\n")
    fail("accepted invalid YAML")
  } catch {
    @mdc.InvalidFrontmatter(line=2, column=8, ..) => ()
    _ => fail("wrong error")
  }
}
