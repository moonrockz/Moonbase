///|
/// A reference profile for the finos/morphir knowledge base, built only with
/// the public `moonrockz/okf` profile API. The library does not ship it.
priv struct MorphirProfile {}

///|
let decision_register : @okf.Register = @okf.Register(
  "decision",
  "Decision Record",
  id_rule=LeadingDigits(width=4),
  state_key="state",
  states=["Proposed", "Accepted", "Superseded", "Withdrawn"],
  transitions=[
    @okf.Transition("Accepted", from=["Proposed"]),
    @okf.Transition("Superseded", from=["Accepted"], obligations=[
      @okf.Obligation::requires_key("superseded_by"),
    ]),
    @okf.Transition("Withdrawn", from=["Proposed", "Accepted"], obligations=[
      @okf.Obligation::requires_key("reason"),
    ]),
  ],
  supersedes_key="supersedes",
  superseded_by_key="superseded_by",
  superseded_states=["Superseded"],
)

///|
let intent_register : @okf.Register = @okf.Register(
  "intent",
  "Intent",
  id_rule=LeadingDigits(width=4),
  state_key="state",
  states=[
    "Backlog", "Refinement", "InProgress", "Released", "Cancelled", "Superseded",
  ],
  transitions=[
    @okf.Transition("Refinement", from=["Backlog"]),
    @okf.Transition("InProgress", from=["Backlog", "Refinement"]),
    @okf.Transition("Released", from=["InProgress"], obligations=[
      @okf.Obligation::requires_key("capability"),
    ]),
    @okf.Transition("Cancelled", from=["Backlog", "Refinement", "InProgress"], obligations=[
      @okf.Obligation::requires_key("reason"),
    ]),
    @okf.Transition("Superseded", obligations=[
      @okf.Obligation::requires_key("superseded_by"),
    ]),
  ],
  superseded_by_key="superseded_by",
  superseded_states=["Superseded"],
  bundle_flag="intent",
)

///|
let morphir_concept_keys : Array[String] = [
  "state", "kind", "breaking", "created", "state_since", "issue", "capability", "superseded_by",
  "reason", "artifacts", "implementation_baselines", "decided", "supersedes",
]

///|
let morphir_bundle_keys : Array[String] = [
  "title", "description", "intent", "system", "capability_bundle", "stale_after_days",
  "sync", "kb_upstream",
]

///|
fn issue_for(
  record : @okf.Record,
  message : String,
  hint? : String,
) -> @okf.Issue {
  @okf.Issue(record.bundle, record.document.path().to_string(), message, hint?)
}

///|
fn decision_records(ctx : @okf.ValidationContext) -> Array[Array[@okf.Record]] {
  ctx.knowledge
  .bundles()
  .iter()
  .map(b => decision_register.records(b))
  .collect()
}

///|
fn is_date(text : String) -> Bool {
  @okf.Instant::parse(text, date_only=true) is Some(_) && text.length() == 10
}

///|
fn decision_rules() -> @okf.RuleSet {
  @okf.RuleSet("morphir-decisions", [
    @okf.Rule("decision-no-id", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for r in records {
          if r.id is None {
            out.push(
              issue_for(
                r, "decision record filename does not start with a numeric id",
              ),
            )
          }
        }
      }
      out
    }),
    @okf.Rule("decision-state-unknown", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for r in records {
          match r.state {
            None => out.push(issue_for(r, "decision record has no `state`"))
            Some(s) if !decision_register.states.contains(s) =>
              out.push(issue_for(r, "`state: \{s}` is not a known state"))
            _ => ()
          }
        }
      }
      out
    }),
    @okf.Rule("decision-decided-missing", Warning, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for r in records {
          if !is_date(r.metadata().text("decided").unwrap_or("")) {
            out.push(
              issue_for(
                r, "decision record has no valid `decided` date (YYYY-MM-DD)",
              ),
            )
          }
        }
      }
      out
    }),
    @okf.Rule("decision-withdrawn-no-reason", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for r in records {
          if r.state == Some("Withdrawn") && r.metadata().text("reason") is None {
            out.push(issue_for(r, "Withdrawn decision has no `reason`"))
          }
        }
      }
      out
    }),
    @okf.Rule("decision-duplicate-id", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for dup in decision_register.duplicates(records) {
          for r in dup.1 {
            out.push(
              issue_for(
                r,
                "decision id `\{dup.0}` is used by \{dup.1.length()} records in \{r.bundle}",
              ),
            )
          }
        }
      }
      out
    }),
    @okf.Rule("decision-supersession", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for i in decision_register.supersession_issues(records) {
          match i {
            MissingSuccessor(r) =>
              out.push(
                issue_for(r, "Superseded decision has no `superseded_by`"),
              )
            UnknownSuccessor(r, id) =>
              out.push(
                issue_for(r, "`superseded_by: \{id}` names no decision record"),
              )
            UnknownPredecessor(r, id) =>
              out.push(
                issue_for(r, "`supersedes: \{id}` names no decision record"),
              )
            NotMutual(a, b) => {
              let x = a.id.unwrap_or("")
              let y = b.id.unwrap_or("")
              out.push(issue_for(a, "\{x} and \{y} do not name each other"))
            }
          }
        }
      }
      out
    }),
  ])
}

///|
fn readme_rules() -> @okf.RuleSet {
  @okf.RuleSet("morphir-layout", [
    @okf.Rule("readme-in-bundle", Error, ctx => {
      let out = []
      for pair in ctx.knowledge.concepts() {
        if pair.1.path().name() == "README.md" {
          out.push(@okf.Issue::at(pair.0, pair.1, "README.md inside a bundle"))
        }
      }
      out
    }),
  ])
}

///|
impl @okf.Profile for MorphirProfile with fn name(_) {
  "morphir"
}

///|
impl @okf.Profile for MorphirProfile with fn vocabulary(_) {
  morphir_concept_keys.map(k => @okf.KeyDefinition(k))
}

///|
impl @okf.Profile for MorphirProfile with fn bundle_keys(_) {
  morphir_bundle_keys.map(k => @okf.KeyDefinition(k))
}

///|
impl @okf.Profile for MorphirProfile with fn registers(_) {
  [decision_register, intent_register]
}

///|
impl @okf.Profile for MorphirProfile with fn reference_fields(_) {
  [{ key: "capability", kind: DocumentRef, }]
}

///|
impl @okf.Profile for MorphirProfile with fn rule_sets(_) {
  [decision_rules(), readme_rules()]
}

///|
impl @okf.Profile for MorphirProfile with fn severities(_) {
  [
    ("link-broken", Error),
    ("link-escapes-bundle", Error),
    ("stray-markdown", Error),
  ]
}

///|
impl @okf.Profile for MorphirProfile with fn options(_) {
  Some(
    @okf.Options::default().update(
      status_default=None,
      nested_logs=RootOnly,
      date_only_instants=true,
    ),
  )
}

///|
fn morphir_profiles() -> Array[&@okf.Profile] {
  [MorphirProfile::{ }]
}

///|
fn morphir_profiled_knowledge() -> @okf.Knowledge raise {
  let profiles = morphir_profiles()
  @okf.discover(
    load_fixture("okf-fixtures/morphir/kb"),
    under=["bundles"],
    options=@okf.effective_options(profiles),
    profiles~,
  )
}

///|
test "the morphir profile lists the same decision records as kb decision list" {
  let knowledge = morphir_profiled_knowledge()
  guard read_golden("decision-list.json") is Array(golden) else {
    fail("bad golden")
  }
  let expected = golden.map(d => {
    guard d
      is {
        "id": String(id),
        "bundle": String(bundle),
        "path": String(path),
        "state": String(state),
        "decided": decided,
        "title": String(title),
        ..
      } else {
      fail("bad decision")
    }
    let decided = match decided {
      String(s) => s
      _ => ""
    }
    (bundle, id, path, state, decided, title)
  })
  let actual = []
  for record in decision_register.all_records(knowledge) {
    actual.push(
      (
        record.bundle,
        record.id.unwrap_or(""),
        record.document.path().to_string(),
        record.state.unwrap_or(""),
        record.metadata().text("decided").unwrap_or(""),
        record.document.display_title(),
      ),
    )
  }
  expected.sort()
  actual.sort()
  assert_eq(actual, expected)
}

///|
test "the morphir profile reproduces kb check exactly" {
  let profiles = morphir_profiles()
  let knowledge = morphir_profiled_knowledge()
  let report = @okf.validate(
    knowledge,
    [@okf.okf_v02_conformance(), @okf.advisory()],
    @okf.FixedClock::at("2026-10-23T00:00:00Z"),
    profiles~,
  )
  let rows = []
  for f in report.findings() {
    rows.push(
      (
        f.severity.to_string(),
        f.rule,
        "kb/bundles/" + f.bundle + f.path,
        f.line.unwrap_or(0),
      ),
    )
  }
  rows.sort()
  assert_eq(rows, golden_findings(["link-broken", "index-description-drift"]))
  assert_eq(report.count(Error), 32)
  assert_eq(report.count(Warning), 1)
  assert_eq(report.count(Info), 0)
}

///|
test "the morphir profile composes without conflicts" {
  assert_eq(@okf.profile_conflicts(morphir_profiles()), [])
}

///|
fn intent_bundle() -> @okf.Bundle raise {
  let profiles = morphir_profiles()
  @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("index.md", "---\nokf_version: \"0.2\"\nintent: true\n---\n# Intent\n"),
      (
        "0001-add-okf.md", "---\ntype: Intent\ntitle: Add OKF\nstate: Backlog\n---\n",
      ),
      (
        "0002-ship-okf.md", "---\ntype: Intent\ntitle: Ship OKF\nstate: InProgress\n---\n",
      ),
      ("caps/okf.md", "---\ntype: Capability\ntitle: OKF\n---\n"),
    ]),
    options=@okf.effective_options(profiles),
    profiles~,
  )
}

///|
test "the intent register applies only to bundles with the intent flag" {
  let b = intent_bundle()
  assert_eq(intent_register.records(b).length(), 2)
  let other = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("0001-x.md", "---\ntype: Intent\nstate: Backlog\n---\n"),
    ]),
  )
  assert_eq(intent_register.records(other).length(), 0)
}

///|
test "intent transitions: allowed, refused for an obligation, not allowed" {
  let b = intent_bundle()
  let records = intent_register.records(b)
  guard intent_register.find(records, "1") is Found(backlog) else {
    fail("no 0001")
  }
  guard intent_register.find(records, "0002") is Found(in_progress) else {
    fail("no 0002")
  }
  assert_eq(intent_register.check_transition(backlog, "Refinement"), Allowed)
  assert_eq(
    intent_register.check_transition(in_progress, "Released"),
    Refused(["capability"]),
  )
  assert_eq(
    intent_register.check_transition(backlog, "Released"),
    NotAllowed(from=Some("Backlog"), to="Released"),
  )
}
