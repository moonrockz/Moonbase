///|
/// A command the CLI, the web UI and the desktop shell all understand.
pub enum Command {
  Help
  Version
}

///|
/// Read a command name. `--help` and `--version` are accepted.
pub fn parse_command(name : String) -> Command? {
  match name {
    "help" | "--help" | "-h" => Some(Help)
    "version" | "--version" | "-V" => Some(Version)
    _ => None
  }
}

///|
/// The name of `command` on the command line.
pub fn command_name(command : Command) -> String {
  match command {
    Help => "help"
    Version => "version"
  }
}

///|
/// The version of this module. It matches the workspace version.
pub fn version() -> String {
  "0.0.2"
}
