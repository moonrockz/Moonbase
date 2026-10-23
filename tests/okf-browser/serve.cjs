// Serves the directory in OKF_BROWSER_DIR on 127.0.0.1:OKF_BROWSER_PORT for the
// Playwright test. The origin private file system needs a secure context, and
// localhost is one.
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const root = process.env.OKF_BROWSER_DIR;
const port = Number(process.env.OKF_BROWSER_PORT || 4173);
const types = { ".html": "text/html", ".js": "text/javascript", ".map": "application/json" };

http
  .createServer((req, res) => {
    const name = req.url === "/" ? "index.html" : decodeURIComponent(req.url.slice(1).split("?")[0]);
    const file = path.join(root, path.normalize(name));
    if (!file.startsWith(root) || !fs.existsSync(file)) {
      res.writeHead(404);
      res.end("not found");
      return;
    }
    res.writeHead(200, { "content-type": types[path.extname(file)] || "application/octet-stream" });
    fs.createReadStream(file).pipe(res);
  })
  .listen(port, "127.0.0.1");
