///|
/// A frontmatter key that a profile defines.
pub(all) struct KeyDefinition {
  key : String
  /// The allowed values, or empty for any value.
  values : ReadOnlyArray[String]
  description : String
} derive(Eq, Debug)

///|
pub fn KeyDefinition::KeyDefinition(
  key : String,
  values~ : ArrayView[String] = [],
  description~ : String = "",
) -> KeyDefinition {
  { key, values: ReadOnlyArray::from_array(values.to_owned()), description, }
}

///|
/// A profile extends OKF with conventions: vocabulary, derived metadata,
/// registers, references, templates and rules. Every method has a default, so
/// a profile implements only what it adds.
pub(open) trait Profile {
  /// The profile name, used in reports.
  fn name(Self) -> String
  /// Concept frontmatter keys that this profile defines.
  fn vocabulary(Self) -> Array[KeyDefinition] = _
  /// Root index frontmatter keys that turn on profile behavior for a bundle.
  fn bundle_keys(Self) -> Array[KeyDefinition] = _
  /// Metadata for a document without frontmatter, from its path and body.
  fn derive_metadata(Self, Document) -> Fields? = _
  /// Typed views of concepts of one type.
  fn registers(Self) -> Array[Register] = _
  /// Frontmatter fields whose values name documents.
  fn reference_fields(Self) -> Array[ReferenceField] = _
  /// Templates for new concepts.
  fn templates(Self) -> Array[Template] = _
  /// Rule sets that validation runs.
  fn rule_sets(Self) -> Array[RuleSet] = _
  /// Options that this profile prefers. The caller's options win.
  fn options(Self) -> Options? = _
  /// Links that the profile adds to the graph for a document, such as links
  /// that its path or frontmatter implies.
  fn relations(Self, Bundle, Document) -> Array[Link] = _
}

///|
impl Profile with fn relations(_, _, _) {
  []
}

///|
impl Profile with fn vocabulary(_) {
  []
}

///|
impl Profile with fn bundle_keys(_) {
  []
}

///|
impl Profile with fn derive_metadata(_, _) {
  None
}

///|
impl Profile with fn registers(_) {
  []
}

///|
impl Profile with fn reference_fields(_) {
  []
}

///|
impl Profile with fn templates(_) {
  []
}

///|
impl Profile with fn rule_sets(_) {
  []
}

///|
impl Profile with fn options(_) {
  None
}

///|
/// The first derived metadata from `profiles`, in order.
fn derive_with(profiles : ArrayView[&Profile], doc : Document) -> Fields? {
  for profile in profiles {
    match profile.derive_metadata(doc) {
      Some(fields) => return Some(fields)
      None => ()
    }
  }
  None
}

///|
pub extend KeyDefinition with Eq::{not_equal, equal}

///|
pub extend KeyDefinition with @debug.Debug::{to_repr}
