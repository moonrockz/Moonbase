///|
test "version prints the contract version" {
  inspect(@contracts.version(), content="0.0.1")
  guard run(["version"]) is Text(text) else { panic() }
  inspect(text, content="moonbase 0.0.1")
}

///|
test "help is the default" {
  guard run([]) is Text(text) else { panic() }
  assert_true(text.has_prefix("Usage: moonbase"))
}

///|
test "an unknown command is rejected" {
  guard run(["nope"]) is Unknown(command) else { panic() }
  inspect(command, content="nope")
}
