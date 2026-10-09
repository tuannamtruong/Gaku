// Web load check: opens the web app in headless Chromium and passes when the page
// returns 2xx, the Leaflet map loads at least one tile, and the browser logs no
// errors. It does not test any feature.
//
// Usage (Playwright must be resolvable through NODE_PATH):
//   NODE_PATH=<dir containing node_modules/playwright> node scripts/infra/test/web-load-check.js http://$ADDR/
//
// Prints the status, cookie names (AWSALB = ALB stickiness) and errors; saves a
// screenshot to the OS temp dir. Exit code 0 = pass, 1 = fail.
const { chromium } = require("playwright");
const path = require("path");
const os = require("os");

(async () => {
  const url = process.argv[2];
  if (!url) {
    console.error("usage: node web-load-check.js <url>");
    process.exit(2);
  }

  const errors = [];
  const browser = await chromium.launch();
  const page = await browser.newPage();
  page.on("console", m => m.type() === "error" && errors.push(m.text()));
  page.on("pageerror", e => errors.push(e.message));
  page.on("response", r => r.status() >= 400 && errors.push(`${r.status()} ${r.url()}`));

  const shot = path.join(os.tmpdir(), "web-load-check.png");
  let res;
  try {
    res = await page.goto(url, { waitUntil: "networkidle" });
    await page.waitForSelector(".leaflet-tile-loaded", { timeout: 30000 });
  } catch (e) {
    errors.push(e.message);
  }
  await page.screenshot({ path: shot });
  const cookies = (await page.context().cookies()).map(c => c.name);
  await browser.close();

  console.log("status    ", res ? res.status() : "no response");
  console.log("cookies   ", cookies.join(", ") || "none");
  console.log("screenshot", shot);
  console.log("errors    ", errors.length ? errors : "none");
  process.exit(res && res.ok() && errors.length === 0 ? 0 : 1);
})();
