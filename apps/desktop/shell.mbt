///|
/// Reply payload for the `mission-control.version` Proton command.
pub struct VersionReply {
  version : String
}

///|
/// The reply the desktop shell sends for `mission-control.version`.
pub fn version_reply() -> VersionReply {
  { version: @contracts.version(), }
}

///|
/// The Proton command the desktop shell exposes for the shared version.
pub fn version_command() -> @proton_contract.Command[
  @proton_contract.EmptyRequest,
  VersionReply,
] {
  @proton_contract.command("mission-control.version")
}

///|
/// The HTML document a Proton window loads. The web UI mounts into `app`.
pub fn document() -> String {
  let version = @contracts.version()
  "<!doctype html><html><head><meta charset=\"utf-8\"><title>Mission Control</title></head><body><h1>Mission Control</h1><p>" +
  version +
  "</p><div id=\"app\"></div></body></html>"
}
