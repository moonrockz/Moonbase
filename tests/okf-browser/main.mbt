///|
/// Publishes the result of the browser checks for the Playwright test.
extern "js" fn publish(result : String) -> Unit =
  #| (result) => { globalThis.okfBrowserResult = result; }

///|
/// Runs the store conformance checks against the origin private file system
/// of the page, in a fresh directory, and publishes `ok` or the failure.
async fn main {
  let result = run() catch { e => "failed: " + e.to_string() }
  publish(result)
}

///|
async fn run() -> String {
  let root = @browser.origin_private_root()
  let store = @browser.BrowserStore(root)
  @conformance.check_store(store, prefix=["okf-conformance"])
  "ok"
}
