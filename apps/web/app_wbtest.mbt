///|
test "the page uses the contract version" {
  inspect(@contracts.version(), content="0.0.1")
}
