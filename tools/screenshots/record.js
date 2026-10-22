// Records the short phone walk-through used at the top of the README.
//   node tools/screenshots/record.js <outDir> [demoUrl]     then it is turned into a GIF by make-gif.sh
const { chromium } = require('playwright');
const fs = require('fs');
const [out, DEMO = 'http://127.0.0.1:5055'] = process.argv.slice(2);
if (!out) { console.error('Usage: node record.js <outDir> [url]'); process.exit(1); }
fs.mkdirSync(out, { recursive: true });

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || '/opt/pw-browsers/chromium' });
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 }, deviceScaleFactor: 1,
    recordVideo: { dir: out, size: { width: 390, height: 844 } },
  });
  const p = await ctx.newPage();
  if (process.env.ROBOTO) {
    await p.route(/fonts\.gstatic\.com|fonts\.googleapis\.com/, r => r.fulfill({ path: process.env.ROBOTO, contentType: 'font/ttf' }));
  }
  await p.goto(DEMO);
  await p.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
  await p.waitForTimeout(3500);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  const t0 = Date.now();
  console.log('READY_AT_MS', t0);
  await p.waitForTimeout(1800);
  await p.getByRole('button', { name: 'Sign in with Microsoft' }).first().click({ force: true });
  await p.waitForTimeout(2600);
  await p.getByRole('checkbox', { name: /Contract draft/ }).first().click({ force: true });
  await p.waitForTimeout(1800);
  await p.getByRole('checkbox', { name: /Contract draft/ }).first().click({ force: true });
  await p.waitForTimeout(1200);
  await p.getByRole('button', { name: /^Print 2 documents/ }).first().click({ force: true });
  await p.waitForTimeout(3500);
  await ctx.close();
  await browser.close();
})();
