///|
async test "the filesystem store meets the store contract" {
  let dir = @afs.tmpdir(prefix="okf-fs-")
  @conformance.check_store(@fs.FsStore(dir))
  @afs.rmdir(dir, recursive=true)
}

///|
async test "the filesystem store refuses symlinks that leave its root" {
  let base = @afs.tmpdir(prefix="okf-fs-link-")
  let root = base + "/root"
  let outside = base + "/outside"
  @afs.mkdir(root, recursive=true)
  @afs.mkdir(outside, recursive=true)
  @afs.write_file(
    outside + "/secret.md",
    "secret",
    create_mode=CreateOrTruncate,
  )
  @afs.write_file(root + "/inside.md", "# In", create_mode=CreateOrTruncate)
  @afs.symlink(target=outside + "/secret.md", root + "/link.md")
  @afs.symlink(target=outside, root + "/out")
  @afs.symlink(target=root + "/inside.md", root + "/alias.md")
  let store = @fs.FsStore(root)
  let names = store.list([]).map(e => e.name)
  assert_eq(names, ["alias.md", "inside.md"])
  let denied = (op : async () -> Unit) => {
    op() catch {
      @provider.PermissionDenied(_) => return true
      _ => return false
    }
    false
  }
  assert_true(
    denied(async fn() { store.read_text(@okf.StorePath("link.md")) |> ignore }),
  )
  assert_true(
    denied(async fn() { store.write_text(@okf.StorePath("link.md"), "x") }),
  )
  assert_true(
    denied(async fn() { store.write_text(@okf.StorePath("out/new.md"), "x") }),
  )
  assert_eq(@afs.read_file(outside + "/secret.md").text(), "secret")
  assert_false(@afs.exists(outside + "/new.md"))
  assert_eq(store.read_text(@okf.StorePath("alias.md")), "# In")
  store.delete(@okf.StorePath("link.md"))
  assert_eq(@afs.read_file(outside + "/secret.md").text(), "secret")
  @afs.rmdir(base, recursive=true)
}
