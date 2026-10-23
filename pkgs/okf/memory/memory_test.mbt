///|
async test "the in-memory store meets the store contract" {
  @conformance.check_store(@memory.MemoryStore())
}

///|
async test "the in-memory store meets the contract under a prefix" {
  @conformance.check_store(@memory.MemoryStore(), prefix=["kb", "bundles"])
}

///|
async test "the in-memory index meets the index contract" {
  @conformance.check_index(@memory.MemoryIndex())
}

///|
async test "the in-memory index meets the search contract" {
  let index = @memory.MemoryIndex()
  @conformance.check_search(index, k => {
    index.build_now(k, @okf.FixedClock::at("2026-10-23T00:00:00Z")) |> ignore
  })
}

///|
async test "a read-only store refuses writes" {
  let store = @memory.MemoryStore(read_only=true)
  let refused = try store.write_text(@okf.StorePath("a.md"), "x") catch {
    @provider.PermissionDenied(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(refused)
}

///|
test "in-memory contents are available synchronously" {
  let store = @memory.MemoryStore()
  store.put(@okf.StorePath("kb/index.md"), "---\nokf_version: \"0.2\"\n---\n")
  store.put(@okf.StorePath("kb/a.md"), "---\ntype: Note\n---\n")
  let knowledge = @okf.discover(store.snapshot())
  assert_eq(knowledge.bundles().length(), 1)
  assert_eq(knowledge.bundles()[0].concepts().length(), 1)
}
