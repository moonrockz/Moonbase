///|
/// A YAML payload and its parsed mapping. Construct with `Frontmatter::Frontmatter`.
/// The representation is hidden so text and parsed YAML always agree.
struct Frontmatter {
  raw : String
  value : @yaml.Yaml
} derive(Debug)

///|
pub extend Frontmatter with @debug.Debug::{to_repr}

///|
/// Validate a YAML payload without delimiter lines and preserve its exact text.
/// Empty and comment-only payloads become empty mappings. Reject invalid YAML,
/// multiple documents and non-mappings. Error positions are one-based and
/// relative to this payload; `parse` translates them to document positions.
pub fn Frontmatter::Frontmatter(raw : String) -> Frontmatter raise ParseError {
  let values = @yaml.Yaml::load_from_string(raw[:]) catch {
    @yaml.YamlError(mark~, info~) =>
      raise InvalidFrontmatter(
        line=mark.line,
        column=mark.col + 1,
        message=info,
      )
  }
  let value = if values.is_empty() {
    @yaml.Yaml::Map({})
  } else if values.length() == 1 && values[0] is Map(_) {
    values[0]
  } else {
    raise InvalidFrontmatter(
      line=1,
      column=1,
      message="frontmatter must be a YAML mapping",
    )
  }
  { raw, value, }
}

///|
/// The original YAML payload, excluding delimiter lines.
pub fn Frontmatter::raw(self : Frontmatter) -> String {
  self.raw
}

///|
/// A deep copy of the parsed YAML mapping. Changes to returned maps and arrays
/// cannot change this frontmatter or make its stored YAML disagree with `raw`.
pub fn Frontmatter::value(self : Frontmatter) -> @yaml.Yaml {
  copy_yaml(self.value)
}

///|
fn copy_yaml(value : @yaml.Yaml) -> @yaml.Yaml {
  match value {
    Map(fields) => {
      let copy = Map([])
      for key, value in fields {
        copy[key] = copy_yaml(value)
      }
      Map(copy)
    }
    Array(values) => Array(values.map(copy_yaml))
    Real(_) | Integer(_) | String(_) | Boolean(_) | Null | BadValue => value
  }
}
