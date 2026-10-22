///|
test "the shell document mounts the web UI" {
  let html = document()
  assert_true(html.contains("id=\"app\""))
  assert_true(html.contains(@contracts.version()))
}

///|
test "the version command is constructed" {
  let _cmd = version_command()
  inspect(version_reply().version, content="0.0.2")
}
