const { test, expect } = require("@playwright/test");

test("the browser store meets the store contract on the origin private file system", async ({ page }) => {
  const errors = [];
  page.on("pageerror", error => errors.push(String(error)));
  await page.goto("/");
  await page.waitForFunction(() => globalThis.okfBrowserResult !== undefined);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => globalThis.okfBrowserResult)).toBe("ok");
});
