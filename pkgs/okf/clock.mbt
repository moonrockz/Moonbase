///|
/// Gives the current instant. The core never reads the system clock; callers
/// supply a clock, so results are deterministic.
pub(open) trait Clock {
  fn now(Self) -> Instant
}

///|
/// A clock that always gives the same instant, for tests and reproducible runs.
pub(all) struct FixedClock {
  instant : Instant
} derive(Eq, Debug)

///|
pub fn FixedClock::FixedClock(instant : Instant) -> FixedClock {
  { instant, }
}

///|
/// A fixed clock from an ISO 8601 datetime. Raises when the text does not parse.
pub fn FixedClock::at(text : String) -> FixedClock raise {
  match Instant::parse(text, date_only=true) {
    Some(instant) => { instant, }
    None => fail("not an ISO 8601 instant: \{text}")
  }
}

///|
pub impl Clock for FixedClock with fn now(self) {
  self.instant
}

///|
/// The calendar date of an instant in UTC, as `YYYY-MM-DD`.
pub fn Instant::date_text(self : Instant) -> String {
  let days = if self.millis >= 0L {
    self.millis / 86400000L
  } else {
    (self.millis - 86399999L) / 86400000L
  }
  let (y, m, d) = civil_from_days(days)
  let pad = (n : Int32, w : Int32) => {
    let s = n.to_string()
    "0".repeat(w - s.length()) + s
  }
  "\{pad(y, 4)}-\{pad(m, 2)}-\{pad(d, 2)}"
}

///|
fn civil_from_days(days : Int64) -> (Int32, Int32, Int32) {
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = if mp < 10L { mp + 3L } else { mp - 9L }
  let y = if m <= 2L { y + 1L } else { y }
  (y.to_int(), m.to_int(), d.to_int())
}

///|
pub extend FixedClock with Eq::{not_equal, equal}

///|
pub extend FixedClock with @debug.Debug::{to_repr}

///|
pub extend FixedClock with Clock::{now}
