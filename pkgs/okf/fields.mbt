///|
/// A point in time, in milliseconds since 1970-01-01T00:00:00Z.
struct Instant {
  millis : Int64
} derive(Eq, Compare, Hash, Debug)

///|
pub fn Instant::of_millis(millis : Int64) -> Instant {
  { millis, }
}

///|
pub fn Instant::millis(self : Instant) -> Int64 {
  self.millis
}

///|
/// Days since 1970-01-01 for a proleptic Gregorian date.
fn days_from_civil(year : Int32, month : Int32, day : Int32) -> Int64 {
  let y = if month <= 2 { year - 1 } else { year }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let mp = (month + 9) % 12
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  (era * 146097 + doe - 719468).to_int64()
}

///|
fn digits(text : String, start : Int32, count : Int32) -> Int32? {
  if start + count > text.length() {
    return None
  }
  let mut value = 0
  for i in start..<(start + count) {
    let c = text[i]
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    2 =>
      if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
/// Parses an ISO 8601 datetime with an explicit offset, such as
/// `2026-06-30T14:00:00Z` or `2026-06-30T14:00:00.250+02:00`. With
/// `date_only=true`, a `YYYY-MM-DD` date is the start of that day in UTC.
pub fn Instant::parse(text : String, date_only~ : Bool = false) -> Instant? {
  let text = text.trim(chars=" \t").to_owned()
  guard digits(text, 0, 4) is Some(year) &&
    text.length() >= 10 &&
    text[4] == '-' &&
    text[7] == '-' &&
    digits(text, 5, 2) is Some(month) &&
    digits(text, 8, 2) is Some(day) else {
    return None
  }
  guard month >= 1 &&
    month <= 12 &&
    day >= 1 &&
    day <= days_in_month(year, month) else {
    return None
  }
  let days = days_from_civil(year, month, day)
  if text.length() == 10 {
    return if date_only { Some({ millis: days * 86400000L, }) } else { None }
  }
  guard (text[10] == 'T' || text[10] == 't' || text[10] == ' ') &&
    digits(text, 11, 2) is Some(hour) &&
    text.length() >= 16 &&
    text[13] == ':' &&
    digits(text, 14, 2) is Some(minute) else {
    return None
  }
  let mut i = 16
  let mut second = 0
  let mut millis = 0
  if i < text.length() && text[i] == ':' {
    guard digits(text, i + 1, 2) is Some(s) else { return None }
    second = s
    i += 3
    if i < text.length() && (text[i] == '.' || text[i] == ',') {
      i += 1
      let mut scale = 100
      while i < text.length() && text[i] >= '0' && text[i] <= '9' {
        millis += (text[i].to_int() - '0'.to_int()) * scale
        scale /= 10
        i += 1
      }
    }
  }
  guard hour <= 23 && minute <= 59 && second <= 60 else { return None }
  guard i < text.length() else { return None }
  let offset_minutes = if text[i] == 'Z' || text[i] == 'z' {
    guard i + 1 == text.length() else { return None }
    0
  } else if text[i] == '+' || text[i] == '-' {
    guard digits(text, i + 1, 2) is Some(oh) else { return None }
    let om = if i + 3 < text.length() && text[i + 3] == ':' {
      guard digits(text, i + 4, 2) is Some(m) && i + 6 == text.length() else {
        return None
      }
      m
    } else {
      guard digits(text, i + 3, 2) is Some(m) && i + 5 == text.length() else {
        return None
      }
      m
    }
    let sign = if text[i] == '-' { -1 } else { 1 }
    sign * (oh * 60 + om)
  } else {
    return None
  }
  let total = days * 86400000L +
    (hour * 3600 + minute * 60 + second - offset_minutes * 60).to_int64() *
    1000L +
    millis.to_int64()
  Some({ millis: total, })
}

///|
/// The lifecycle status of a concept (OKF v0.2, section 5.4).
pub(all) enum Status {
  Draft
  Stable
  Deprecated
  Unknown(String)
} derive(Eq, Debug)

///|
pub fn Status::parse(text : String) -> Status {
  match text.to_lower() {
    "draft" => Draft
    "stable" => Stable
    "deprecated" => Deprecated
    _ => Unknown(text)
  }
}

///|
pub fn Status::to_string(self : Status) -> String {
  match self {
    Draft => "draft"
    Stable => "stable"
    Deprecated => "deprecated"
    Unknown(text) => text
  }
}

///|
/// Who produced or verified knowledge (OKF v0.2, section 7).
pub(all) enum Actor {
  /// An automated producer, `<producer>/<version>`.
  Producer(name~ : String, version~ : String)
  /// A person, `human:<id>`.
  Human(String)
  /// A process, `process:<id>`.
  Process(String)
  /// Any other form, kept as written.
  Other(String)
} derive(Eq, Debug)

///|
pub fn Actor::parse(text : String) -> Actor {
  if text.has_prefix("human:") {
    return Human(text[6:].to_owned())
  }
  if text.has_prefix("process:") {
    return Process(text[8:].to_owned())
  }
  match text.rev_find("/") {
    Some(i) if i > 0 && i < text.length() - 1 && !text.contains(":") =>
      Producer(name=text[:i].to_owned(), version=text[i + 1:].to_owned())
    _ => Other(text)
  }
}

///|
pub fn Actor::is_human(self : Actor) -> Bool {
  self is Human(_)
}

///|
/// One `sources` entry (OKF v0.2, section 5.1).
pub(all) struct Source {
  resource : String
  id : String?
  title : String?
  author : String?
  usage_count : Int32?
  last_modified : String?
  usage_window : UsageWindow?
} derive(Eq, Debug)

///|
/// A `usage_window` mapping with its raw `from` and `to` texts.
pub(all) struct UsageWindow {
  from : String?
  to : String?
} derive(Eq, Debug)

///|
/// A `{by, at}` record, as in `generated` and `verified`.
pub(all) struct Attribution {
  by : Actor
  at : String?
} derive(Eq, Debug)

///|
/// The derived trust tier (OKF v0.2, section 5.3).
pub(all) enum TrustTier {
  Unverified
  MachineConfirmed
  HumanReviewed
} derive(Eq, Compare, Debug)

///|
/// One `parameters` entry of an Attested Computation.
pub(all) struct Parameter {
  name : String
  type_ : String?
  required : Bool
} derive(Eq, Debug)

///|
/// The `executor` of an Attested Computation.
pub(all) struct Executor {
  resource : String?
  receipt : Array[String]
} derive(Eq, Debug)

///|
fn usage_window_of(fields : Fields) -> UsageWindow {
  { from: fields.text("from"), to: fields.text("to"), }
}

///|
fn attribution_of(fields : Fields) -> Attribution? {
  match fields.text("by") {
    Some(by) => Some({ by: Actor::parse(by), at: fields.text("at"), })
    None => None
  }
}

///|
/// The OKF `type`, or `None` when it is missing or empty.
pub fn Metadata::concept_type(self : Metadata) -> String? {
  match self.text("type") {
    Some(t) if t.trim(chars=" \t").length() > 0 => Some(t)
    _ => None
  }
}

///|
pub fn Metadata::title(self : Metadata) -> String? {
  self.text("title")
}

///|
pub fn Metadata::description(self : Metadata) -> String? {
  self.text("description")
}

///|
pub fn Metadata::resource(self : Metadata) -> String? {
  self.text("resource")
}

///|
pub fn Metadata::tags(self : Metadata) -> Array[String] {
  self.texts("tags")
}

///|
/// The top-level `usage_window`.
pub fn Metadata::usage_window(self : Metadata) -> UsageWindow? {
  match self.mappings("usage_window") {
    [fields, ..] => Some(usage_window_of(fields))
    [] => None
  }
}

///|
/// The `sources` entries that have a `resource`. Entries without one are left out.
pub fn Metadata::sources(self : Metadata) -> Array[Source] {
  self
  .mappings("sources")
  .iter()
  .filter_map(fields => {
    match fields.text("resource") {
      Some(resource) =>
        Some({
          resource,
          id: fields.text("id"),
          title: fields.text("title"),
          author: fields.text("author"),
          usage_count: fields.int("usage_count"),
          last_modified: fields.text("last_modified"),
          usage_window: match fields.get("usage_window") {
            Some(Mapping(window)) => Some(usage_window_of(window))
            _ => None
          },
        })
      None => None
    }
  })
  .collect()
}

///|
/// `generated`, or with `v01_fields` a v0.1 `timestamp` as `generated.at`.
pub fn Metadata::generated(
  self : Metadata,
  options~ : Options = Options::default(),
) -> Attribution? {
  match self.mappings("generated") {
    [fields, ..] => attribution_of(fields)
    [] =>
      if options.v01_fields {
        match self.text("timestamp") {
          Some(at) => Some({ by: Other(""), at: Some(at), })
          None => None
        }
      } else {
        None
      }
  }
}

///|
/// `verified` as a list. A single mapping is a list with one entry.
pub fn Metadata::verified(self : Metadata) -> Array[Attribution] {
  self.mappings("verified").iter().filter_map(attribution_of).collect()
}

///|
/// The trust tier, derived from `verified` only.
pub fn Metadata::trust_tier(self : Metadata) -> TrustTier {
  let verified = self.verified()
  if verified.is_empty() {
    Unverified
  } else if verified.any(a => a.by.is_human()) {
    HumanReviewed
  } else {
    MachineConfirmed
  }
}

///|
/// The written `status`, or `None` when it is absent.
pub fn Metadata::status(self : Metadata) -> Status? {
  match self.text("status") {
    Some(text) => Some(Status::parse(text))
    None => None
  }
}

///|
/// The status after the default of `options` applies.
pub fn Metadata::effective_status(
  self : Metadata,
  options~ : Options = Options::default(),
) -> Status? {
  match self.status() {
    Some(status) => Some(status)
    None => options.status_default
  }
}

///|
/// The raw `stale_after` text.
pub fn Metadata::stale_after(self : Metadata) -> String? {
  self.text("stale_after")
}

///|
/// True when `now` is at or after `stale_after`. A value that does not parse
/// under `options` gives false.
pub fn Metadata::is_stale(
  self : Metadata,
  now : Instant,
  options~ : Options = Options::default(),
) -> Bool {
  match self.stale_after() {
    Some(text) =>
      match Instant::parse(text, date_only=options.date_only_instants) {
        Some(limit) => now >= limit
        None => false
      }
    None => false
  }
}

///|
pub fn Metadata::runtime(self : Metadata) -> String? {
  self.text("runtime")
}

///|
pub fn Metadata::parameters(self : Metadata) -> Array[Parameter] {
  self
  .mappings("parameters")
  .iter()
  .filter_map(fields => {
    match fields.text("name") {
      Some(name) =>
        Some({
          name,
          type_: fields.text("type"),
          required: fields.bool("required").unwrap_or(false),
        })
      None => None
    }
  })
  .collect()
}

///|
pub fn Metadata::computation(self : Metadata) -> String? {
  self.text("computation")
}

///|
pub fn Metadata::executor(self : Metadata) -> Executor? {
  match self.mappings("executor") {
    [fields, ..] =>
      Some({
        resource: fields.text("resource"),
        receipt: fields.texts("receipt"),
      })
    [] => None
  }
}

///|
/// The `attester.resource` of an Attested Computation.
pub fn Metadata::attester(self : Metadata) -> String? {
  match self.mappings("attester") {
    [fields, ..] => fields.text("resource")
    [] => None
  }
}

///|
/// The keys that OKF v0.2 defines for concepts.
pub let okf_concept_keys : ReadOnlyArray[String] = [
  "type", "title", "description", "resource", "tags", "sources", "usage_window",
  "generated", "verified", "status", "stale_after", "runtime", "parameters", "computation",
  "executor", "attester",
]

///|
pub extend Instant with Eq::{not_equal, equal}

///|
pub extend Instant with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Instant with Hash::{hash, hash_combine}

///|
pub extend Instant with @debug.Debug::{to_repr}

///|
pub extend Status with Eq::{not_equal, equal}

///|
pub extend Status with @debug.Debug::{to_repr}

///|
pub extend Actor with Eq::{not_equal, equal}

///|
pub extend Actor with @debug.Debug::{to_repr}

///|
pub extend Source with Eq::{not_equal, equal}

///|
pub extend Source with @debug.Debug::{to_repr}

///|
pub extend UsageWindow with Eq::{not_equal, equal}

///|
pub extend UsageWindow with @debug.Debug::{to_repr}

///|
pub extend Attribution with Eq::{not_equal, equal}

///|
pub extend Attribution with @debug.Debug::{to_repr}

///|
pub extend TrustTier with Eq::{not_equal, equal}

///|
pub extend TrustTier with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend TrustTier with @debug.Debug::{to_repr}

///|
pub extend Parameter with Eq::{not_equal, equal}

///|
pub extend Parameter with @debug.Debug::{to_repr}

///|
pub extend Executor with Eq::{not_equal, equal}

///|
pub extend Executor with @debug.Debug::{to_repr}
