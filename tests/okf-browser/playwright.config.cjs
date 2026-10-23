// Runs the browser store conformance checks in headless Chromium. Start it
// with `mise run test:browser`, which builds the page first.
const port = Number(process.env.OKF_BROWSER_PORT || 4173);

module.exports = {
  testDir: ".",
  testMatch: "*.spec.cjs",
  outputDir: "../../_build/okf-browser/results",
  workers: 1,
  retries: 0,
  timeout: 60_000,
  reporter: "list",
  use: { baseURL: `http://127.0.0.1:${port}`, headless: true },
  projects: [{ name: "chromium", use: { browserName: "chromium" } }],
  webServer: {
    command: "node serve.cjs",
    url: `http://127.0.0.1:${port}/index.html`,
    reuseExistingServer: false,
  },
};
