///|
/// What `run` decided to do with the arguments.
pub enum Run {
  Text(String)
  Unknown(String)
}

///|
pub fn usage() -> String {
  "Usage: moonbase <command>\n\nCommands:\n  help       Print this help\n  version    Print the version"
}

///|
/// Run one invocation. `args` does not include the program name.
pub fn run(args : Array[String]) -> Run {
  let name = match args {
    [] => "help"
    [command, ..] => command
  }
  match @contracts.parse_command(name) {
    Some(Help) => Text(usage())
    Some(Version) => Text("moonbase " + @contracts.version())
    None => Unknown(name)
  }
}
