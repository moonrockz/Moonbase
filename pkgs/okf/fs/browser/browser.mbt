///|
/// A `FileSystemDirectoryHandle` of the File System Access API.
#external
pub type DirectoryHandle

///|
/// The settled result of a browser call.
#external
priv type CallResult

///|
extern "js" fn CallResult::ok(self : CallResult) -> Bool =
  #| (r) => r.ok

///|
extern "js" fn CallResult::code(self : CallResult) -> String =
  #| (r) => r.code || ""

///|
extern "js" fn CallResult::message(self : CallResult) -> String =
  #| (r) => r.message || ""

///|
extern "js" fn CallResult::text(self : CallResult) -> String =
  #| (r) => r.value

///|
extern "js" fn CallResult::bytes(self : CallResult) -> Bytes =
  #| (r) => r.value

///|
extern "js" fn CallResult::number(self : CallResult) -> Double =
  #| (r) => r.value

///|
extern "js" fn CallResult::handle(self : CallResult) -> DirectoryHandle =
  #| (r) => r.value

///|
extern "js" fn browser_call(
  root : DirectoryHandle,
  op : String,
  path : String,
  text : String,
  bytes : Bytes,
) -> @js_async.Promise[CallResult] =
  #| (root, op, path, text, bytes) => (async () => {
  #|   try {
  #|     const parts = path === "" ? [] : path.split("/");
  #|     const dirOf = async (segs, create) => {
  #|       let d = root;
  #|       for (const s of segs) d = await d.getDirectoryHandle(s, { create });
  #|       return d;
  #|     };
  #|     const parent = () => parts.slice(0, -1);
  #|     const name = () => parts[parts.length - 1];
  #|     switch (op) {
  #|       case "list": {
  #|         const d = await dirOf(parts, false);
  #|         const out = [];
  #|         for await (const [n, h] of d.entries()) out.push((h.kind === "directory" ? "d\t" : "f\t") + n);
  #|         return { ok: true, value: out.join("\u0000") };
  #|       }
  #|       case "readText": {
  #|         const fh = await (await dirOf(parent(), false)).getFileHandle(name());
  #|         return { ok: true, value: await (await fh.getFile()).text() };
  #|       }
  #|       case "readBytes": {
  #|         const fh = await (await dirOf(parent(), false)).getFileHandle(name());
  #|         return { ok: true, value: new Uint8Array(await (await fh.getFile()).arrayBuffer()) };
  #|       }
  #|       case "writeText":
  #|       case "writeBytes": {
  #|         const fh = await (await dirOf(parent(), true)).getFileHandle(name(), { create: true });
  #|         const w = await fh.createWritable();
  #|         await w.write(op === "writeText" ? text : bytes);
  #|         await w.close();
  #|         return { ok: true, value: null };
  #|       }
  #|       case "delete": {
  #|         try {
  #|           await (await dirOf(parent(), false)).removeEntry(name());
  #|         } catch (e) {
  #|           if (!e || (e.name !== "NotFoundError" && e.name !== "TypeMismatchError")) throw e;
  #|         }
  #|         return { ok: true, value: null };
  #|       }
  #|       case "mtime": {
  #|         const fh = await (await dirOf(parent(), false)).getFileHandle(name());
  #|         return { ok: true, value: (await fh.getFile()).lastModified };
  #|       }
  #|     }
  #|     return { ok: false, code: "TypeError", message: "unknown operation " + op };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) };
  #|   }
  #| })()

///|
extern "js" fn storage_root() -> @js_async.Promise[CallResult] =
  #| () => (async () => {
  #|   try {
  #|     return { ok: true, value: await globalThis.navigator.storage.getDirectory() };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) };
  #|   }
  #| })()

///|
extern "js" fn picker() -> @js_async.Promise[CallResult] =
  #| () => (async () => {
  #|   try {
  #|     return { ok: true, value: await globalThis.showDirectoryPicker({ mode: "readwrite" }) };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) };
  #|   }
  #| })()

///|
fn store_error(path : String, result : CallResult) -> @provider.StoreError {
  match result.code() {
    "NotFoundError" | "TypeMismatchError" => NotFound(path)
    "NotAllowedError" | "SecurityError" | "NoModificationAllowedError" =>
      PermissionDenied(path)
    _ => Failed(path, result.message())
  }
}

///|
async fn settle(
  path : String,
  promise : @js_async.Promise[CallResult],
) -> CallResult raise @provider.StoreError {
  let result = promise.wait() catch { e => raise Failed(path, e.to_string()) }
  if result.ok() {
    result
  } else {
    raise store_error(path, result)
  }
}

///|
/// The root of the origin private file system (`navigator.storage.getDirectory()`).
pub async fn origin_private_root() -> DirectoryHandle raise @provider.StoreError {
  settle("", storage_root()).handle()
}

///|
/// Asks the user to select a directory, with read and write access
/// (`showDirectoryPicker`). It needs a user gesture in the page.
pub async fn pick_directory() -> DirectoryHandle raise @provider.StoreError {
  settle("", picker()).handle()
}

///|
/// A document store over a directory handle of the File System Access API.
/// The caller supplies the handle: the origin private file system root, or a
/// directory that the user selected.
struct BrowserStore {
  root : DirectoryHandle
}

///|
pub fn BrowserStore::BrowserStore(root : DirectoryHandle) -> BrowserStore {
  { root, }
}

///|
async fn BrowserStore::call(
  self : BrowserStore,
  op : String,
  path : String,
  text~ : String = "",
  bytes~ : Bytes = b"",
) -> CallResult raise @provider.StoreError {
  settle(path, browser_call(self.root, op, path, text, bytes))
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn list(self, dir) {
  let path = dir.iter().collect().join("/")
  let encoded = self.call("list", path).text()
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
pub impl @provider.DocumentStore for BrowserStore with fn read_text(self, path) {
  self.call("readText", path.to_string()).text()
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn read_bytes(self, path) {
  self.call("readBytes", path.to_string()).bytes()
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn write_text(
  self,
  path,
  text,
) {
  self.call("writeText", path.to_string(), text~) |> ignore
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn write_bytes(
  self,
  path,
  bytes,
) {
  self.call("writeBytes", path.to_string(), bytes~) |> ignore
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn delete(self, path) {
  self.call("delete", path.to_string()) |> ignore
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn modified(self, path) {
  let ms = self.call("mtime", path.to_string()).number()
  Some(@okf.Instant::of_millis(ms.to_int64()))
}

///|
pub extend BrowserStore with @provider.DocumentStore::{
  read_bytes,
  list,
  write_bytes,
  delete,
  modified,
  read_text,
  write_text,
}

///|
/// An in-memory stand-in for a `FileSystemDirectoryHandle`, for tests outside
/// a browser. With `writable=false`, writes and deletes fail with
/// `NotAllowedError`, as a read-only handle does.
pub extern "js" fn memory_directory_handle(writable : Bool) -> DirectoryHandle =
  #| (writable) => {
  #|   const fail = (name, message) => { const e = new Error(message); e.name = name; throw e; };
  #|   const makeFile = (name) => ({ kind: "file", name, data: new Uint8Array(), lastModified: Date.now() });
  #|   const fileHandle = (node) => ({
  #|     kind: "file", name: node.name,
  #|     async getFile() {
  #|       const data = node.data;
  #|       return {
  #|         lastModified: node.lastModified,
  #|         async text() { return new TextDecoder().decode(data); },
  #|         async arrayBuffer() { return data.slice().buffer; },
  #|       };
  #|     },
  #|     async createWritable() {
  #|       if (!writable) fail("NotAllowedError", "read-only handle");
  #|       let pending = new Uint8Array();
  #|       return {
  #|         async write(chunk) {
  #|           pending = typeof chunk === "string" ? new TextEncoder().encode(chunk) : new Uint8Array(chunk);
  #|         },
  #|         async close() { node.data = pending; node.lastModified = Date.now(); },
  #|       };
  #|     },
  #|   });
  #|   const dirHandle = (node) => ({
  #|     kind: "directory", name: node.name,
  #|     async getDirectoryHandle(name, opts) {
  #|       let child = node.children.get(name);
  #|       if (!child) {
  #|         if (!(opts && opts.create)) fail("NotFoundError", name);
  #|         if (!writable) fail("NotAllowedError", "read-only handle");
  #|         child = { kind: "directory", name, children: new Map() };
  #|         node.children.set(name, child);
  #|       }
  #|       if (child.kind !== "directory") fail("TypeMismatchError", name);
  #|       return dirHandle(child);
  #|     },
  #|     async getFileHandle(name, opts) {
  #|       let child = node.children.get(name);
  #|       if (!child) {
  #|         if (!(opts && opts.create)) fail("NotFoundError", name);
  #|         if (!writable) fail("NotAllowedError", "read-only handle");
  #|         child = makeFile(name);
  #|         node.children.set(name, child);
  #|       }
  #|       if (child.kind !== "file") fail("TypeMismatchError", name);
  #|       return fileHandle(child);
  #|     },
  #|     async removeEntry(name) {
  #|       if (!node.children.has(name)) fail("NotFoundError", name);
  #|       if (!writable) fail("NotAllowedError", "read-only handle");
  #|       node.children.delete(name);
  #|     },
  #|     async *entries() {
  #|       for (const [name, child] of node.children) {
  #|         yield [name, child.kind === "directory" ? dirHandle(child) : fileHandle(child)];
  #|       }
  #|     },
  #|   });
  #|   return dirHandle({ kind: "directory", name: "", children: new Map() });
  #| }
