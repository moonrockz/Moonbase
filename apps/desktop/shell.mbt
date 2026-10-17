///|
/// Reply payload for the `moonbase.version` Proton command.
pub struct VersionReply {
  version : String
}

///|
/// The reply the desktop shell sends for `moonbase.version`.
pub fn version_reply() -> VersionReply {
  { version: @contracts.version(), }
}

///|
/// The Proton command the desktop shell exposes for the shared version.
pub fn version_command() -> @proton_contract.Command[
  @proton_contract.EmptyRequest,
  VersionReply,
] {
  @proton_contract.command("moonbase.version")
}

///|
/// The HTML document a Proton window loads. The web UI mounts into `app`.
pub fn document() -> String {
  let version = @contracts.version()
  "<!doctype html><html><head><meta charset=\"utf-8\"><title>Moonbase</title></head><body><h1>Moonbase</h1><p>" +
  version +
  "</p><div id=\"app\"></div></body></html>"
}
