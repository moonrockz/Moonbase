///|
test "setting an equal value reports no change" {
  let text = "---\ntype: Metric\nstatus: stable\n---\nBody\n"
  let r = @edit.set_key(text, "status", "stable")
  assert_eq(r.changed, false)
  assert_eq(r.text, text)
}

///|
test "CRLF files keep CRLF and change one line only" {
  let text = "---\r\ntype: Metric\r\nstatus: draft\r\n---\r\nBody\r\n"
  let r = @edit.set_key(text, "status", "stable")
  assert_eq(r.text, "---\r\ntype: Metric\r\nstatus: stable\r\n---\r\nBody\r\n")
  assert_eq(r.changed, true)
}

///|
test "a new key goes after the last frontmatter line, after a block" {
  let text = "---\ntype: Metric\nsources:\n  - resource: https://a\n---\n# A\n"
  let r = @edit.set_key(text, "status", "deprecated")
  assert_eq(
    r.text,
    "---\ntype: Metric\nsources:\n  - resource: https://a\nstatus: deprecated\n---\n# A\n",
  )
}

///|
test "values that need quotes" {
  let r = @edit.set_key("---\ntype: A\n---\n", "title", "Revenue: net")
  assert_eq(r.text, "---\ntype: A\ntitle: \"Revenue: net\"\n---\n")
  assert_eq(@edit.yaml_scalar("say \"hi\", ok"), "\"say \\\"hi\\\", ok\"")
  assert_eq(@edit.yaml_scalar(""), "\"\"")
}

///|
test "removing a key removes its value lines only" {
  let text = "---\ntype: A\nstale_after: 2026-01-01T00:00:00Z\ntags:\n  - x\n# comment\nstatus: draft\n---\nBody\n"
  let r = @edit.remove_key(text, "tags")
  assert_eq(
    r.text,
    "---\ntype: A\nstale_after: 2026-01-01T00:00:00Z\n# comment\nstatus: draft\n---\nBody\n",
  )
  let r2 = @edit.remove_key(r.text, "stale_after")
  assert_eq(r2.text, "---\ntype: A\n# comment\nstatus: draft\n---\nBody\n")
}

///|
test "a key on a document without frontmatter adds a block" {
  let r = @edit.set_key("# A\n", "type", "Note")
  assert_eq(r.text, "---\ntype: Note\n---\n# A\n")
}

///|
test "index entries go after the last entry or into a new section" {
  let index = "# Tables\n\n* [Orders](/tables/orders.md) - One row per order\n\n# Other\n\n* [X](/x.md)\n"
  let r = @edit.add_index_entry(
    index,
    "Tables",
    @edit.index_entry_line(
      "Customers",
      "/tables/customers.md",
      description="One row per customer",
    ),
  )
  assert_eq(
    r.text,
    "# Tables\n\n* [Orders](/tables/orders.md) - One row per order\n* [Customers](/tables/customers.md) - One row per customer\n\n# Other\n\n* [X](/x.md)\n",
  )
  let r2 = @edit.add_index_entry(
    index, "Metrics", "* [Revenue](/metrics/revenue.md)",
  )
  assert_eq(
    r2.text,
    index + "\n# Metrics\n\n* [Revenue](/metrics/revenue.md)\n",
  )
}

///|
test "refresh changes only the description and keeps the link text" {
  let index = "# Metrics\n\n* [Daily *revenue*](/metrics/revenue.md) - Old text\n"
  let r = @edit.refresh_index_entry(
    index, "/metrics/revenue.md", "Net revenue per day",
  )
  assert_eq(
    r.text,
    "# Metrics\n\n* [Daily *revenue*](/metrics/revenue.md) - Net revenue per day\n",
  )
}

///|
test "log entries: existing date, new newest date, older date" {
  let log = "# Log\n\n## 2026-10-20\n\n* **Update**: Added revenue metric.\n\n## 2026-09-01\n\n* **Creation**: Started.\n"
  let r = @edit.add_log_entry(
    log,
    "2026-10-23",
    "Added churn.",
    label="Creation",
  )
  assert_eq(
    r.text,
    "# Log\n\n## 2026-10-23\n\n* **Creation**: Added churn.\n\n## 2026-10-20\n\n* **Update**: Added revenue metric.\n\n## 2026-09-01\n\n* **Creation**: Started.\n",
  )
  let r2 = @edit.add_log_entry(
    log,
    "2026-10-20",
    "Fixed a typo.",
    label="Update",
  )
  assert_eq(
    r2.text,
    "# Log\n\n## 2026-10-20\n\n* **Update**: Added revenue metric.\n* **Update**: Fixed a typo.\n\n## 2026-09-01\n\n* **Creation**: Started.\n",
  )
  let r3 = @edit.add_log_entry(log, "2026-09-15", "Middle.")
  assert_eq(
    r3.text,
    "# Log\n\n## 2026-10-20\n\n* **Update**: Added revenue metric.\n\n## 2026-09-15\n\n* Middle.\n\n## 2026-09-01\n\n* **Creation**: Started.\n",
  )
}

///|
test "regions keep their preamble and report no change for equal content" {
  let text = "# Index\n\nHand-written.\n\n<!-- intent:index -->\n* [A](/a.md)\n"
  let same = @edit.replace_region(text, "intent:index", "* [A](/a.md)\n")
  assert_eq(same.changed, false)
  let next = @edit.replace_region(text, "intent:index", "* [B](/b.md)\n")
  assert_eq(
    next.text,
    "# Index\n\nHand-written.\n\n<!-- intent:index -->\n* [B](/b.md)\n",
  )
  let missing = try
    @edit.replace_region("# Index\n", "intent:index", "")
  catch {
    NoRegion(name) => name
    _ => ""
  } noraise {
    _ => ""
  }
  assert_eq(missing, "intent:index")
}

///|
fn sample_bundle() -> @okf.Bundle raise {
  @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      (
        "index.md", "---\nokf_version: \"0.2\"\n---\n# Tables\n\n* [Orders](/tables/orders.md) - Orders\n",
      ),
      ("log.md", "# Log\n\n## 2026-10-20\n\n* **Creation**: Started.\n"),
      (
        "tables/orders.md", "---\ntype: Table\ntitle: Orders\ndescription: Orders\n---\n# Orders\n",
      ),
      ("decisions/index.md", "# Decisions\n"),
    ]),
  )
}

///|
test "new concepts: reserved, escaping and existing paths are refused" {
  let b = sample_bundle()
  assert_true(refusal(b, "/tables/index.md") is Some(ReservedName(_)))
  assert_true(refusal(b, "/../x.md") is Some(EscapesBundle(_)))
  assert_true(refusal(b, "/tables/orders.md") is Some(AlreadyExists(_)))
  assert_true(refusal(b, "/tables/customers.md") is None)
}

///|
test "target index: the nearest sub-index, else the root index" {
  let b = sample_bundle()
  assert_eq(
    @edit.target_index(b, @okf.BundlePath("/decisions/0042-use-yaml.md")).map(p => {
      p.to_string()
    }),
    Some("/decisions/index.md"),
  )
  assert_eq(
    @edit.target_index(b, @okf.BundlePath("/metrics/revenue.md")).map(p => {
      p.to_string()
    }),
    Some("/index.md"),
  )
}

///|
test "planning a concept writes nothing until the plan applies" {
  let b = sample_bundle()
  let set = @okf.DocumentSet::of_texts([])
  let plan = @edit.plan_add_concept(
    b, "/metrics/revenue.md", "Metric", "Revenue", "Net revenue per day", "2026-10-23",
  )
  let paths = plan.changes().map(c => c.path().to_string())
  assert_eq(paths.iter().collect(), ["metrics/revenue.md", "index.md", "log.md"])
  assert_eq(set.length(), 0)
  guard plan.changes()[0] is Create(text~, ..) else {
    fail("expected a create")
  }
  assert_true(
    text.has_prefix(
      "---\ntype: Metric\ntitle: Revenue\ndescription: Net revenue per day\n---\n",
    ),
  )
  guard plan.changes()[1] is Update(after~, ..) else {
    fail("expected an update")
  }
  assert_true(
    after.contains(
      "# Metric\n\n* [Revenue](/metrics/revenue.md) - Net revenue per day\n",
    ),
  )
  guard plan.changes()[2] is Update(after~, ..) else {
    fail("expected an update")
  }
  assert_true(
    after.contains(
      "## 2026-10-23\n\n* **Creation**: Added [Revenue](/metrics/revenue.md).\n",
    ),
  )
  let applied = plan.apply_to(set)
  assert_eq(applied.length(), 3)
  assert_true(plan.render().has_prefix("create metrics/revenue.md\n+ ---\n"))
}

///|
fn refusal(b : @okf.Bundle, path : String) -> @edit.PathRefused? {
  try @edit.check_new_concept_path(b, path) catch {
    e => Some(e)
  } noraise {
    _ => None
  }
}

///|
test "values with line breaks, null-like values and entry markers stay strings" {
  assert_eq(@edit.yaml_scalar("a\nb"), "\"a\\nb\"")
  assert_eq(@edit.yaml_scalar("tab\there"), "\"tab\\there\"")
  assert_eq(@edit.yaml_scalar("null"), "\"null\"")
  assert_eq(@edit.yaml_scalar("~"), "\"~\"")
  assert_eq(@edit.yaml_scalar("- item"), "\"- item\"")
  assert_eq(@edit.yaml_scalar("plain"), "plain")
  for
    value in [
      "a\nb\r\nc", "null", "~", "- item", "? key", "line\tend", "quote \" and \\ slash",
    ] {
    let text = @edit.set_key("---\ntype: A\n---\n", "title", value).text
    let doc = @okf.Document(
      @okf.BundlePath("/a.md"),
      @okf.StorePath("a.md"),
      text,
    )
    assert_eq(doc.metadata().keys(), ["type", "title"], msg=value)
    assert_eq(doc.metadata().text("title"), Some(value), msg=value)
  }
}

///|
fn edit_error(
  f : () -> @edit.EditResult raise @edit.EditError,
) -> @edit.EditError? {
  try f() catch {
    e => Some(e)
  } noraise {
    _ => None
  }
}

///|
test "frontmatter keys and raw values cannot add keys or close the block" {
  let text = "---\ntype: A\n---\n"
  assert_eq(
    edit_error(() => @edit.set_key(text, "a: b", "x")),
    Some(InvalidKey("a: b")),
  )
  assert_eq(
    edit_error(() => @edit.set_key(text, "a\n---", "x")),
    Some(InvalidKey("a\n---")),
  )
  assert_eq(
    edit_error(() => @edit.set_key(text, "", "x")),
    Some(InvalidKey("")),
  )
  assert_eq(
    edit_error(() => @edit.set_key(text, "- item", "x")),
    Some(InvalidKey("- item")),
  )
  assert_eq(
    edit_error(() => {
      @edit.set_raw_keys(text, [("owner", Some("x\nstatus: done"))])
    }),
    Some(InvalidValue(key="owner", value="x\nstatus: done")),
  )
  // An indented continuation is a valid block value.
  let r = @edit.set_raw_keys(text, [("tags", Some("\n  - a\n  - b"))])
  let doc = @okf.Document(
    @okf.BundlePath("/a.md"),
    @okf.StorePath("a.md"),
    r.text,
  )
  assert_eq(doc.metadata().texts("tags"), ["a", "b"])
  assert_eq(doc.metadata().keys(), ["type", "tags"])
}

///|
test "log dates must be real calendar dates" {
  let log = "# Log\n"
  assert_eq(
    edit_error(() => @edit.add_log_entry(log, "2026-9-1", "x")),
    Some(InvalidDate("2026-9-1")),
  )
  assert_eq(
    edit_error(() => @edit.add_log_entry(log, "2026-02-30", "x")),
    Some(InvalidDate("2026-02-30")),
  )
  assert_eq(
    edit_error(() => @edit.add_log_entry(log, "", "x")),
    Some(InvalidDate("")),
  )
  assert_eq(edit_error(() => @edit.add_log_entry(log, "2026-02-28", "x")), None)
}

///|
test "new concept fields are checked" {
  let refused = try
    @edit.new_concept_text("Note", "A", "B", fields=[
      ("owner", "x\nstatus: done"),
    ])
  catch {
    InvalidValue(..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(refused)
}

///|
test "a transition cannot replace the checked state through extra keys" {
  let reg = @okf.Register(
    "intent",
    "Intent",
    state_key="state",
    states=["Backlog", "Review", "Done"],
    transitions=[@okf.Transition("Review", from=["Backlog"])],
  )
  let b = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("0001-a.md", "---\ntype: Intent\nstate: Backlog\n---\n"),
    ]),
  )
  let record = reg.records(b)[0]
  let refused = try
    @edit.plan_transition(reg, record, "Review", extra=[("state", "Done")])
  catch {
    @edit.StateKeyInExtra(key) => key
    _ => ""
  } noraise {
    _ => ""
  }
  assert_eq(refused, "state")
  let no_state = @okf.Register("note", "Note")
  let missing = try @edit.plan_transition(no_state, record, "Review") catch {
    @edit.NoStateKey(register~) => register
    _ => ""
  } noraise {
    _ => ""
  }
  assert_eq(missing, "note")
}

///|
test "only plain frontmatter keys are accepted" {
  let text = "---\ntype: A\nstate: B\n---\n"
  for bad in ["\"state\"", "'type'", "state ", "&a x", "[a", "!t x", "", "a b"] {
    assert_eq(
      edit_error(() => @edit.set_key(text, bad, "x")),
      Some(InvalidKey(bad)),
      msg=bad,
    )
  }
  for
    good in ["state", "x_1", "owner.team", "stale-after", "_private", "9lives"] {
    assert_eq(edit_error(() => @edit.set_key(text, good, "x")), None, msg=good)
  }
}

///|
test "log entries and index entries must be one line" {
  assert_eq(
    edit_error(() => {
      @edit.add_log_entry("# Log\n", "2026-01-01", "x\n## 2099-01-01\n* forged")
    }),
    Some(LineBreak(field="message", text="x\n## 2099-01-01\n* forged")),
  )
  assert_eq(
    edit_error(() => {
      @edit.add_log_entry("# Log\n", "2026-01-01", "x", label="A\nB")
    }),
    Some(LineBreak(field="label", text="A\nB")),
  )
  let refused = try @edit.index_entry_line("Bad\n# Section", "/a.md") catch {
    LineBreak(field~, ..) => field
    _ => ""
  } noraise {
    _ => ""
  }
  assert_eq(refused, "title")
}

///|
test "a transition refuses a preview whose frontmatter would not parse" {
  // The record already has a duplicate-prone layout: the extra value is valid
  // YAML on its own, but the key collides with an existing key.
  let reg = @okf.Register(
    "intent",
    "Intent",
    state_key="state",
    states=["Backlog", "Review"],
    transitions=[@okf.Transition("Review", from=["Backlog"])],
  )
  let b = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("0001-a.md", "---\ntype: Intent\nstate: Backlog\nnote: x\n---\n"),
    ]),
  )
  let record = reg.records(b)[0]
  let refused = try
    @edit.plan_transition(reg, record, "Review", extra=[("note", "[unclosed")])
  catch {
    @edit.PreviewInvalid(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(refused)
}
