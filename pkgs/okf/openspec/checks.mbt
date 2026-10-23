///|
fn spec_docs(
  ctx : @okf.ValidationContext,
) -> Array[(@okf.Bundle, @okf.Document)] {
  ctx.knowledge
  .concepts()
  .iter()
  .filter(p => {
    match p.1.metadata().concept_type() {
      Some(t) => t == specification_type || t == delta_type
      None => false
    }
  })
  .collect()
}

///|
fn all_requirements(model : SpecModel) -> Array[Requirement] {
  let out = model.requirements.copy()
  for d in model.deltas {
    if d.op is (Added | Modified) {
      for r in d.requirements {
        out.push(r)
      }
    }
  }
  out
}

///|
fn model_of(doc : @okf.Document) -> SpecModel {
  parse_spec(doc.metadata().text("capability").unwrap_or(""), doc.prose_lines())
}

///|
fn check_no_scenario(ctx : @okf.ValidationContext) -> Array[@okf.Issue] {
  let out = []
  for pair in spec_docs(ctx) {
    for r in all_requirements(model_of(pair.1)) {
      if r.scenarios.is_empty() {
        out.push(
          @okf.Issue::at(
            pair.0,
            pair.1,
            "the requirement `\{r.name}` has no scenario",
            line=r.line,
          ),
        )
      }
    }
  }
  out
}

///|
fn check_no_shall(ctx : @okf.ValidationContext) -> Array[@okf.Issue] {
  let out = []
  for pair in spec_docs(ctx) {
    for r in all_requirements(model_of(pair.1)) {
      if !r.text.contains("SHALL") && !r.text.contains("MUST") {
        out.push(
          @okf.Issue::at(
            pair.0,
            pair.1,
            "the requirement `\{r.name}` has no SHALL or MUST",
            line=r.line,
          ),
        )
      }
    }
  }
  out
}

///|
fn check_scenario_headings(ctx : @okf.ValidationContext) -> Array[@okf.Issue] {
  let out = []
  for pair in spec_docs(ctx) {
    for line in pair.1.prose_lines() {
      let t = line.1.trim(chars=" \t").to_owned()
      let wrong = match heading(t) {
        Some((level, text)) => level != 4 && text.has_prefix("Scenario:")
        None => t.has_prefix("- Scenario:") || t.has_prefix("**Scenario")
      }
      if wrong {
        out.push(
          @okf.Issue::at(
            pair.0,
            pair.1,
            "a scenario must use a `####` heading",
            line=line.0,
            hint="Write `#### Scenario: <name>`.",
          ),
        )
      }
    }
  }
  out
}

///|
/// The main spec of each capability.
fn main_specs(ctx : @okf.ValidationContext) -> Map[String, SpecModel] {
  let out : Map[String, SpecModel] = Map([])
  for pair in spec_docs(ctx) {
    if pair.1.metadata().concept_type() == Some(specification_type) {
      let m = model_of(pair.1)
      out[m.capability] = m
    }
  }
  out
}

///|
fn check_modified_unknown(ctx : @okf.ValidationContext) -> Array[@okf.Issue] {
  let mains = main_specs(ctx)
  let out = []
  for pair in spec_docs(ctx) {
    guard pair.1.metadata().concept_type() == Some(delta_type) else { continue }
    let m = model_of(pair.1)
    guard mains.get(m.capability) is Some(main) else { continue }
    for d in m.deltas {
      if d.op is (Modified | Removed) {
        for r in d.requirements {
          if !main.requirements.any(x => x.name == r.name) {
            out.push(
              @okf.Issue::at(
                pair.0,
                pair.1,
                "`\{r.name}` matches no requirement of `\{m.capability}`",
                line=r.line,
              ),
            )
          }
        }
      }
    }
  }
  out
}

///|
fn check_unknown_capability(ctx : @okf.ValidationContext) -> Array[@okf.Issue] {
  let mains = main_specs(ctx)
  let out = []
  for pair in spec_docs(ctx) {
    guard pair.1.metadata().concept_type() == Some(delta_type) else { continue }
    let m = model_of(pair.1)
    if !mains.contains(m.capability) && m.deltas.any(d => !(d.op is Added)) {
      out.push(
        @okf.Issue::at(
          pair.0,
          pair.1,
          "the capability `\{m.capability}` does not exist, and the delta does not only add requirements",
        ),
      )
    }
  }
  out
}

///|
/// The OpenSpec checks, which mirror `openspec validate --strict`.
pub fn openspec_checks() -> @okf.RuleSet {
  @okf.RuleSet("openspec", [
    @okf.Rule("openspec-requirement-no-scenario", Error, check_no_scenario),
    @okf.Rule("openspec-requirement-no-shall", Error, check_no_shall),
    @okf.Rule("openspec-scenario-heading", Error, check_scenario_headings),
    @okf.Rule("openspec-modified-unknown", Error, check_modified_unknown),
    @okf.Rule(
      "openspec-delta-unknown-capability",
      Error,
      check_unknown_capability,
    ),
  ])
}
