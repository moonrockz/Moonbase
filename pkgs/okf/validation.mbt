///|
/// The severity of a finding. Errors sort first.
pub(all) enum Severity {
  Error
  Warning
  Info
} derive(Eq, Compare, Hash, Debug)

///|
pub fn Severity::to_string(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warn"
    Info => "info"
  }
}

///|
/// One validation result.
pub(all) struct Finding {
  severity : Severity
  rule : String
  /// The bundle label, or `""` for a file outside every bundle.
  bundle : String
  /// The document path: a bundle path, or a store path for a stray.
  path : String
  line : Int32?
  message : String
  hint : String?
} derive(Eq, Debug)

///|
/// What a rule reports. Validation adds the rule name and the severity.
pub(all) struct Issue {
  bundle : String
  path : String
  line : Int32?
  message : String
  hint : String?
} derive(Eq, Debug)

///|
pub fn Issue::Issue(
  bundle : String,
  path : String,
  message : String,
  line? : Int32,
  hint? : String,
) -> Issue {
  { bundle, path, line, message, hint, }
}

///|
/// An issue about one document of a bundle.
pub fn Issue::at(
  bundle : Bundle,
  doc : Document,
  message : String,
  line? : Int32,
  hint? : String,
) -> Issue {
  { bundle: bundle.label(), path: doc.path().to_string(), line, message, hint, }
}

///|
/// The inputs that every rule can read.
pub(all) struct ValidationContext {
  knowledge : Knowledge
  graph : Graph
  now : Instant
  options : Options
  vocabulary : Vocabulary
  profiles : Array[&Profile]
}

///|
/// One named check with a default severity.
struct Rule {
  name : String
  severity : Severity
  check : (ValidationContext) -> Array[Issue]
}

///|
pub fn Rule::Rule(
  name : String,
  severity : Severity,
  check : (ValidationContext) -> Array[Issue],
) -> Rule {
  { name, severity, check, }
}

///|
pub fn Rule::name(self : Rule) -> String {
  self.name
}

///|
pub fn Rule::severity(self : Rule) -> Severity {
  self.severity
}

///|
/// A named group of rules.
struct RuleSet {
  name : String
  rules : ReadOnlyArray[Rule]
}

///|
pub fn RuleSet::RuleSet(name : String, rules : ArrayView[Rule]) -> RuleSet {
  { name, rules: ReadOnlyArray::from_array(rules.to_owned()), }
}

///|
pub fn RuleSet::name(self : RuleSet) -> String {
  self.name
}

///|
pub fn RuleSet::rules(self : RuleSet) -> ReadOnlyArray[Rule] {
  self.rules
}

///|
/// How a caller adjusts validation.
pub(all) struct ValidationConfig {
  /// Severity changes, by rule name.
  overrides : Map[String, Severity]
  /// Rules that do not run, by name.
  disabled : Array[String]
}

///|
pub fn ValidationConfig::ValidationConfig(
  overrides~ : ArrayView[(String, Severity)] = [],
  disabled~ : ArrayView[String] = [],
) -> ValidationConfig {
  let map : Map[String, Severity] = Map([])
  for pair in overrides {
    map[pair.0] = pair.1
  }
  { overrides: map, disabled: disabled.to_owned(), }
}

///|
/// The sorted findings of one validation run.
struct Report {
  findings : ReadOnlyArray[Finding]
}

///|
fn severity_rank(s : Severity) -> Int32 {
  match s {
    Error => 0
    Warning => 1
    Info => 2
  }
}

///|
fn compare_findings(a : Finding, b : Finding) -> Int32 {
  let c = severity_rank(a.severity).compare(severity_rank(b.severity))
  if c != 0 {
    return c
  }
  let c = lexical_compare(a.bundle, b.bundle)
  if c != 0 {
    return c
  }
  let c = lexical_compare(a.path, b.path)
  if c != 0 {
    return c
  }
  let c = a.line.unwrap_or(0).compare(b.line.unwrap_or(0))
  if c != 0 {
    return c
  }
  let c = lexical_compare(a.rule, b.rule)
  if c != 0 {
    return c
  }
  lexical_compare(a.message, b.message)
}

///|
/// A report from findings, sorted by severity, bundle, path, line and rule.
pub fn Report::Report(findings : ArrayView[Finding]) -> Report {
  let sorted = findings.to_owned()
  sorted.sort_by(compare_findings)
  { findings: ReadOnlyArray::from_array(sorted), }
}

///|
pub fn Report::findings(self : Report) -> ReadOnlyArray[Finding] {
  self.findings
}

///|
pub fn Report::count(self : Report, severity : Severity) -> Int32 {
  self.findings.iter().filter(f => f.severity == severity).count()
}

///|
/// True when the result fails: any error, or any warning in strict mode.
pub fn Report::fails(self : Report, strict~ : Bool = false) -> Bool {
  self.count(Error) > 0 || (strict && self.count(Warning) > 0)
}

///|
/// The findings of one rule.
pub fn Report::of_rule(self : Report, rule : String) -> Array[Finding] {
  self.findings.iter().filter(f => f.rule == rule).collect()
}

///|
/// Runs the rule sets over the knowledge and returns the sorted findings.
pub fn validate(
  knowledge : Knowledge,
  rule_sets : ArrayView[RuleSet],
  clock : &Clock,
  config~ : ValidationConfig = ValidationConfig(),
  resolver? : &LinkResolver,
  profiles~ : ArrayView[&Profile] = [],
) -> Report {
  let graph = Graph::build(knowledge, resolver?, profiles~)
  let context = {
    knowledge,
    graph,
    now: clock.now(),
    options: knowledge.options(),
    vocabulary: Vocabulary::of_profiles(profiles),
    profiles: profiles.to_owned(),
  }
  let findings = []
  let sets = rule_sets.to_owned()
  for profile in profiles {
    for set in profile.rule_sets() {
      sets.push(set)
    }
  }
  let profile_severity : Map[String, Severity] = Map([])
  for profile in profiles {
    for pair in profile.severities() {
      if !profile_severity.contains(pair.0) {
        profile_severity[pair.0] = pair.1
      }
    }
  }
  for set in sets {
    for rule in set.rules {
      guard !config.disabled.contains(rule.name) else { continue }
      let severity = match config.overrides.get(rule.name) {
        Some(s) => s
        None => profile_severity.get(rule.name).unwrap_or(rule.severity)
      }
      for issue in (rule.check)(context) {
        findings.push({
          severity,
          rule: rule.name,
          bundle: issue.bundle,
          path: issue.path,
          line: issue.line,
          message: issue.message,
          hint: issue.hint,
        })
      }
    }
  }
  Report(findings)
}

///|
/// The keys that validation treats as known: OKF keys and profile keys.
struct Vocabulary {
  concept_keys : Map[String, String]
  bundle_keys : Map[String, String]
}

///|
/// The OKF vocabulary plus the vocabulary of each profile. The value of each
/// key is the name of the profile that defines it, or `okf`.
pub fn Vocabulary::of_profiles(profiles : ArrayView[&Profile]) -> Vocabulary {
  let concept_keys : Map[String, String] = Map([])
  for key in okf_concept_keys {
    concept_keys[key] = "okf"
  }
  let bundle_keys : Map[String, String] = Map([])
  bundle_keys["okf_version"] = "okf"
  for profile in profiles {
    for def in profile.vocabulary() {
      if !concept_keys.contains(def.key) {
        concept_keys[def.key] = profile.name()
      }
    }
    for def in profile.bundle_keys() {
      if !bundle_keys.contains(def.key) {
        bundle_keys[def.key] = profile.name()
      }
    }
  }
  { concept_keys, bundle_keys, }
}

///|
pub fn Vocabulary::knows(self : Vocabulary, key : String) -> Bool {
  self.concept_keys.contains(key)
}

///|
pub fn Vocabulary::knows_bundle_key(self : Vocabulary, key : String) -> Bool {
  self.bundle_keys.contains(key)
}

///|
pub extend Severity with Eq::{not_equal, equal}

///|
pub extend Severity with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Severity with Hash::{hash, hash_combine}

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
pub extend Finding with Eq::{not_equal, equal}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
pub extend Issue with Eq::{not_equal, equal}

///|
pub extend Issue with @debug.Debug::{to_repr}
