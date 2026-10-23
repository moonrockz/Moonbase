///|
/// The base for relative links and relative path-valued fields.
pub(all) enum LinkBase {
  /// The directory of the file that holds the link (OKF v0.2, section 6.2).
  FileDirectory
  /// The bundle root, as many OKF bundles write paths in practice.
  BundleRoot
} derive(Eq, Debug)

///|
/// Which `log.md` files a bundle loads.
pub(all) enum NestedLogs {
  /// A `log.md` at any depth (OKF v0.2, section 3.1).
  AllLevels
  /// Only the bundle-root `log.md`. Nested ones are reported as ignored.
  RootOnly
} derive(Eq, Debug)

///|
/// The options for each known difference between the OKF v0.2 specification
/// and existing tools. `Options::default()` follows the specification.
pub(all) struct Options {
  /// The base for relative links.
  link_base : LinkBase
  /// The status of a concept without `status`. OKF v0.2 says `stable`.
  status_default : Status?
  /// Which `log.md` files load.
  nested_logs : NestedLogs
  /// Accept `YYYY-MM-DD` dates where OKF v0.2 requires a datetime.
  date_only_instants : Bool
  /// Read the v0.1 forms `timestamp` (as `generated.at`) and a `# Citations`
  /// section (as sources).
  v01_fields : Bool
  /// Count links from `index.md` files as backlinks for orphan detection.
  index_links_count : Bool
} derive(Eq, Debug)

///|
/// The OKF v0.2 behavior.
pub fn Options::default() -> Options {
  {
    link_base: FileDirectory,
    status_default: Some(Stable),
    nested_logs: AllLevels,
    date_only_instants: false,
    v01_fields: false,
    index_links_count: false,
  }
}

///|
/// A copy with the given options changed.
pub fn Options::update(
  self : Options,
  link_base? : LinkBase,
  status_default? : Status?,
  nested_logs? : NestedLogs,
  date_only_instants? : Bool,
  v01_fields? : Bool,
  index_links_count? : Bool,
) -> Options {
  {
    link_base: link_base.unwrap_or(self.link_base),
    status_default: match status_default {
      Some(value) => value
      None => self.status_default
    },
    nested_logs: nested_logs.unwrap_or(self.nested_logs),
    date_only_instants: date_only_instants.unwrap_or(self.date_only_instants),
    v01_fields: v01_fields.unwrap_or(self.v01_fields),
    index_links_count: index_links_count.unwrap_or(self.index_links_count),
  }
}

///|
pub extend LinkBase with Eq::{not_equal, equal}

///|
pub extend LinkBase with @debug.Debug::{to_repr}

///|
pub extend NestedLogs with Eq::{not_equal, equal}

///|
pub extend NestedLogs with @debug.Debug::{to_repr}

///|
pub extend Options with Eq::{not_equal, equal}

///|
pub extend Options with @debug.Debug::{to_repr}
