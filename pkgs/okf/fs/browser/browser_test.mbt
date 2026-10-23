///|
async test "the browser store meets the store contract on a stand-in handle" {
  @conformance.check_store(
    @browser.BrowserStore(@browser.memory_directory_handle(true)),
  )
}

///|
async test "the browser store reports a permission error and writes nothing" {
  let store = @browser.BrowserStore(@browser.memory_directory_handle(false))
  let denied = try store.write_text(@okf.StorePath("a.md"), "x") catch {
    @provider.PermissionDenied(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(denied)
  assert_eq(store.list([]).length(), 0)
}
