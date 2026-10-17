# moonbase-web

The Moonbase web UI. It is a [Rabbita](https://github.com/moonbit-community/rabbita) page. The page reads `version()` from `moonrockz/moonbase-contracts` and mounts into an element whose id is `app`.

```shell
moon build apps/web --target js
moon run apps/web --target js
```

`moon run` needs a page with `<div id="app"></div>`. Rabbita's dev server is [Warren](https://github.com/moonbit-community/warren). This package is JavaScript only.
