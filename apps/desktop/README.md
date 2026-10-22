# mission-control-desktop

The desktop shell. It defines the Proton command `mission-control.version` with `moonbit-community/proton_contract` and the HTML document a Proton window loads. The document contains `<div id="app"></div>`, which is where `apps/web` mounts.

The native window is `moonbit-community/proton`. That package links the CEF runtime, and `moon build` runs its prebuild only when the CEF SDK is installed (`proton_cli cef setup`). This module does not import `moonbit-community/proton` yet, so CI can check and build the shell without that SDK. The next step is a native `main` that calls `@proton.html(document()).identifier("dev.moonrockz.mission-control").run_or_abort()`.
