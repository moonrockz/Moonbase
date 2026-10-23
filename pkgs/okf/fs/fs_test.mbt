///|
async test "the filesystem store meets the store contract" {
  let dir = @afs.tmpdir(prefix="okf-fs-")
  @conformance.check_store(@fs.FsStore(dir))
  @afs.rmdir(dir, recursive=true)
}
