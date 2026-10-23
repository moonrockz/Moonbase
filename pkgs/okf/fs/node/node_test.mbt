///|
async test "the Node.js store meets the store contract" {
  let dir = @node.temporary_directory("okf-node-")
  @conformance.check_store(@node.NodeStore(dir))
  @node.remove_directory(dir)
}

///|
async test "the Node.js store reports missing directories" {
  let store = @node.NodeStore("/definitely/not/here/okf")
  let missing = try store.list([]) catch {
    @provider.NotFound(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(missing)
}
