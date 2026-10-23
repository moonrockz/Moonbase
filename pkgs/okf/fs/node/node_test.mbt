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

///|
extern "js" fn fs_sync(op : String, a : String, b : String) -> String =
  #| (op, a, b) => {
  #|   const fs = globalThis.process.getBuiltinModule("node:fs");
  #|   if (op === "mkdir") { fs.mkdirSync(a, { recursive: true }); return ""; }
  #|   if (op === "write") { fs.writeFileSync(a, b); return ""; }
  #|   if (op === "read") return fs.readFileSync(a, "utf8");
  #|   if (op === "exists") return fs.existsSync(a) ? "yes" : "no";
  #|   if (op === "symlink") { fs.symlinkSync(a, b); return ""; }
  #|   return "";
  #| }

///|
async test "the Node.js store refuses symlinks that leave its root" {
  let base = @node.temporary_directory("okf-node-link-")
  let root = base + "/root"
  let outside = base + "/outside"
  fs_sync("mkdir", root, "") |> ignore
  fs_sync("mkdir", outside, "") |> ignore
  fs_sync("write", outside + "/secret.md", "secret") |> ignore
  fs_sync("write", root + "/inside.md", "# In") |> ignore
  fs_sync("symlink", outside + "/secret.md", root + "/link.md") |> ignore
  fs_sync("symlink", outside, root + "/out") |> ignore
  fs_sync("symlink", root + "/inside.md", root + "/alias.md") |> ignore
  let store = @node.NodeStore(root)
  assert_eq(store.list([]).map(e => e.name), ["alias.md", "inside.md"])
  let read_denied = try store.read_text(@okf.StorePath("link.md")) catch {
    @provider.PermissionDenied(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(read_denied)
  let write_denied = try
    store.write_text(@okf.StorePath("link.md"), "x")
  catch {
    @provider.PermissionDenied(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(write_denied)
  let dir_denied = try
    store.write_text(@okf.StorePath("out/new.md"), "x")
  catch {
    @provider.PermissionDenied(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(dir_denied)
  assert_eq(fs_sync("read", outside + "/secret.md", ""), "secret")
  assert_eq(fs_sync("exists", outside + "/new.md", ""), "no")
  assert_eq(store.read_text(@okf.StorePath("alias.md")), "# In")
  store.delete(@okf.StorePath("link.md"))
  assert_eq(fs_sync("read", outside + "/secret.md", ""), "secret")
  @node.remove_directory(base)
}
