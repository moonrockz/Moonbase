///|
/// The settled result of a Node.js call: `ok`, an error `code` such as
/// `ENOENT`, a `message`, and a `value`.
#external
priv type NodeResult

///|
extern "js" fn NodeResult::ok(self : NodeResult) -> Bool =
  #| (r) => r.ok

///|
extern "js" fn NodeResult::code(self : NodeResult) -> String =
  #| (r) => r.code || ""

///|
extern "js" fn NodeResult::message(self : NodeResult) -> String =
  #| (r) => r.message || ""

///|
extern "js" fn NodeResult::text(self : NodeResult) -> String =
  #| (r) => r.value

///|
extern "js" fn NodeResult::bytes(self : NodeResult) -> Bytes =
  #| (r) => new Uint8Array(r.value.buffer, r.value.byteOffset, r.value.byteLength)

///|
extern "js" fn NodeResult::number(self : NodeResult) -> Double =
  #| (r) => r.value

///|
/// True when the runtime gives the Node.js file system API through
/// `process.getBuiltinModule` (Node.js 20.16 or later, Bun and Deno).
pub extern "js" fn node_available() -> Bool =
  #| () => !!(globalThis.process && typeof globalThis.process.getBuiltinModule === "function")

///|
extern "js" fn node_call(
  op : String,
  path : String,
  text : String,
  bytes : Bytes,
) -> @js_async.Promise[NodeResult] =
  #| (op, path, text, bytes) => (async () => {
  #|   try {
  #|     const fs = globalThis.process.getBuiltinModule("node:fs/promises");
  #|     const p = globalThis.process.getBuiltinModule("node:path");
  #|     switch (op) {
  #|       case "list": {
  #|         const entries = await fs.readdir(path, { withFileTypes: true });
  #|         const out = [];
  #|         for (const e of entries) {
  #|           if (e.isDirectory()) out.push("d\t" + e.name);
  #|           else if (e.isFile() || e.isSymbolicLink()) out.push("f\t" + e.name);
  #|         }
  #|         return { ok: true, value: out.join("\u0000") };
  #|       }
  #|       case "readText": return { ok: true, value: await fs.readFile(path, "utf8") };
  #|       case "readBytes": return { ok: true, value: await fs.readFile(path) };
  #|       case "writeText":
  #|         await fs.mkdir(p.dirname(path), { recursive: true });
  #|         await fs.writeFile(path, text, "utf8");
  #|         return { ok: true, value: null };
  #|       case "writeBytes":
  #|         await fs.mkdir(p.dirname(path), { recursive: true });
  #|         await fs.writeFile(path, bytes);
  #|         return { ok: true, value: null };
  #|       case "delete":
  #|         try { await fs.unlink(path); } catch (e) { if (e.code !== "ENOENT") throw e; }
  #|         return { ok: true, value: null };
  #|       case "mtime": return { ok: true, value: (await fs.stat(path)).mtimeMs };
  #|       case "mkdtemp": {
  #|         const os = globalThis.process.getBuiltinModule("node:os");
  #|         return { ok: true, value: await fs.mkdtemp(p.join(os.tmpdir(), path)) };
  #|       }
  #|       case "rmdir": await fs.rm(path, { recursive: true, force: true }); return { ok: true, value: null };
  #|     }
  #|     return { ok: false, code: "EINVAL", message: "unknown operation " + op };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.code) || "", message: String(e && e.message || e) };
  #|   }
  #| })()

///|
async fn call(
  op : String,
  path : String,
  text~ : String = "",
  bytes~ : Bytes = b"",
) -> NodeResult raise @provider.StoreError {
  if !node_available() {
    raise Failed(
      path, "the Node.js file system API is not available; it needs Node.js 20.16 or later",
    )
  }
  let result = node_call(op, path, text, bytes).wait() catch {
    e => raise Failed(path, e.to_string())
  }
  if result.ok() {
    return result
  }
  match result.code() {
    "ENOENT" | "ENOTDIR" => raise NotFound(path)
    "EACCES" | "EPERM" | "EROFS" => raise PermissionDenied(path)
    _ => raise Failed(path, result.message())
  }
}

///|
/// A document store over a directory, through the Node.js file system API.
struct NodeStore {
  root : String
}

///|
pub fn NodeStore::NodeStore(root : String) -> NodeStore {
  let root = if root.length() > 1 && root.has_suffix("/") {
    root[:root.length() - 1].to_owned()
  } else {
    root
  }
  { root, }
}

///|
pub fn NodeStore::root(self : NodeStore) -> String {
  self.root
}

///|
/// A new, empty temporary directory whose name starts with `prefix`.
pub async fn temporary_directory(
  prefix : String,
) -> String raise @provider.StoreError {
  call("mkdtemp", prefix).text()
}

///|
/// Removes a directory and everything in it.
pub async fn remove_directory(path : String) -> Unit raise @provider.StoreError {
  call("rmdir", path) |> ignore
}

///|
fn NodeStore::full(self : NodeStore, segments : ArrayView[String]) -> String {
  if segments.is_empty() {
    self.root
  } else {
    self.root + "/" + segments.iter().collect().join("/")
  }
}

///|
fn NodeStore::file(self : NodeStore, path : @okf.StorePath) -> String {
  self.full(path.segments().iter().collect())
}

///|
pub impl @provider.DocumentStore for NodeStore with fn list(self, dir) {
  let encoded = call("list", self.full(dir)).text()
  let out = []
  if encoded.length() > 0 {
    for item in encoded.split("\u0000") {
      let item = item.to_owned()
      let kind : @provider.EntryKind = if item.has_prefix("d\t") {
        Directory
      } else {
        File
      }
      out.push(@provider.StoreEntry::{ name: item[2:].to_owned(), kind, })
    }
  }
  out.sort_by((a, b) => @okf.lexical_compare(a.name, b.name))
  out
}

///|
pub impl @provider.DocumentStore for NodeStore with fn read_text(self, path) {
  call("readText", self.file(path)).text()
}

///|
pub impl @provider.DocumentStore for NodeStore with fn read_bytes(self, path) {
  call("readBytes", self.file(path)).bytes()
}

///|
pub impl @provider.DocumentStore for NodeStore with fn write_text(
  self,
  path,
  text,
) {
  call("writeText", self.file(path), text~) |> ignore
}

///|
pub impl @provider.DocumentStore for NodeStore with fn write_bytes(
  self,
  path,
  bytes,
) {
  call("writeBytes", self.file(path), bytes~) |> ignore
}

///|
pub impl @provider.DocumentStore for NodeStore with fn delete(self, path) {
  call("delete", self.file(path)) |> ignore
}

///|
pub impl @provider.DocumentStore for NodeStore with fn modified(self, path) {
  let ms = call("mtime", self.file(path)).number()
  Some(@okf.Instant::of_millis(ms.to_int64()))
}

///|
pub extend NodeStore with @provider.DocumentStore::{
  read_bytes,
  list,
  write_bytes,
  delete,
  modified,
  read_text,
  write_text,
}
