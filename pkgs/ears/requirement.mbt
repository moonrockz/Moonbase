///|
pub(all) enum Pattern {
  Ubiquitous
  StateDriven
  EventDriven
  OptionalFeature
  UnwantedBehaviour
  Complex
} derive(Eq, Debug)

///|
pub(all) enum Trigger {
  Event(String)
  Unwanted(String)
} derive(Eq, Debug)

///|
/// A validated EARS sentence. Only the parser can construct a requirement.
/// Free-text clauses retain their case and punctuation, with whitespace folded.
struct Requirement {
  feature : String?
  preconditions : ReadOnlyArray[String]
  trigger : Trigger?
  system : String
  response : String
} derive(Eq, Debug)

///|
pub fn Requirement::feature(self : Requirement) -> String? {
  self.feature
}

///|
pub fn Requirement::preconditions(self : Requirement) -> ReadOnlyArray[String] {
  self.preconditions
}

///|
pub fn Requirement::trigger(self : Requirement) -> Trigger? {
  self.trigger
}

///|
pub fn Requirement::system(self : Requirement) -> String {
  self.system
}

///|
pub fn Requirement::response(self : Requirement) -> String {
  self.response
}

///|
pub fn Requirement::pattern(self : Requirement) -> Pattern {
  let count = (if self.feature is Some(_) { 1 } else { 0 }) +
    self.preconditions.length() +
    (if self.trigger is Some(_) { 1 } else { 0 })
  if count > 1 {
    return Complex
  }
  if self.feature is Some(_) {
    return OptionalFeature
  }
  if !self.preconditions.is_empty() {
    return StateDriven
  }
  match self.trigger {
    Some(Event(_)) => EventDriven
    Some(Unwanted(_)) => UnwantedBehaviour
    None => Ubiquitous
  }
}

///|
/// Render canonical keyword case and spacing. Response punctuation is retained.
pub fn Requirement::to_string(self : Requirement) -> String {
  let clauses = []
  if self.feature is Some(feature) {
    clauses.push("Where " + feature)
  }
  for state in self.preconditions {
    clauses.push("While " + state)
  }
  match self.trigger {
    Some(Event(event)) => clauses.push("When " + event)
    Some(Unwanted(event)) => clauses.push("If " + event)
    None => ()
  }
  let system = if self.trigger is Some(Unwanted(_)) {
    "then the "
  } else if clauses.is_empty() {
    "The "
  } else {
    "the "
  }
  clauses.push(system + self.system + " shall " + self.response)
  clauses.join(", ")
}

///|
pub(all) suberror ParseError {
  EmptyRequirement
  ExpectedSystem
  MissingShall
  MissingResponse
  EmptyClause(keyword~ : String)
  MissingSeparator
  MissingThen
  InvalidClauseOrder
} derive(Eq, Debug)

///|
pub extend Pattern with Eq::{equal, not_equal}

///|
pub extend Pattern with @debug.Debug::{to_repr}

///|
pub extend Trigger with Eq::{equal, not_equal}

///|
pub extend Trigger with @debug.Debug::{to_repr}

///|
pub extend Requirement with Eq::{equal, not_equal}

///|
pub extend Requirement with @debug.Debug::{to_repr}

///|
pub extend ParseError with Eq::{equal, not_equal}

///|
pub extend ParseError with @debug.Debug::{to_repr}
