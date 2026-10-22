///|
test "command names" {
  inspect(command_name(Help), content="help")
  inspect(command_name(Version), content="version")
  guard parse_command("version") is Some(Version) else { panic() }
  guard parse_command("nope") is None else { panic() }
}

///|
test "version is the workspace version" {
  inspect(version(), content="0.0.2")
}
