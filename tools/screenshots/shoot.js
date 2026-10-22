// Takes every picture used in the README and docs/ from a running copy of the app.
//
//   node tools/screenshots/shoot.js <outDir> [demoUrl] [googleUrl] [microsoftUrl] [mixedUrl]
//
// See tools/screenshots/README.md for how to start the four servers it expects.
// Needs Playwright and a Chromium (set CHROMIUM=/path/to/chrome if it is not found).
const { chromium } = require('playwright');
const fs = require('fs');

const [out, DEMO = 'http://127.0.0.1:5055', GOOGLE = 'http://127.0.0.1:5056',
  MICROSOFT = 'http://127.0.0.1:5057', MIXED = 'http://127.0.0.1:5058'] = process.argv.slice(2);
if (!out) { console.error('Usage: node shoot.js <outDir> [urls...]'); process.exit(1); }
fs.mkdirSync(out, { recursive: true });

const PHONE = { width: 390, height: 844 };
const PANEL = { width: 1024, height: 600 };
const WIDE = { width: 1280, height: 1500 };
const failures = [];

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || '/opt/pw-browsers/chromium' });

  async function open(url, size, { fonts = true } = {}) {
    const ctx = await browser.newContext({ viewport: size, deviceScaleFactor: 2 });
    const page = await ctx.newPage();
    if (fonts && process.env.ROBOTO) {
      await page.route(/fonts\.gstatic\.com|fonts\.googleapis\.com/, r =>
        r.fulfill({ path: process.env.ROBOTO, contentType: 'font/ttf' }));
    }
    await page.goto(url);
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
    await page.waitForTimeout(3500);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(800);
    return page;
  }
  const button = (p, name) => p.getByRole('button', { name }).first();
  const press = async (p, name) => { await button(p, name).click({ force: true }); await p.waitForTimeout(1500); };
  const shot = async (p, name, clip) => {
    await p.waitForTimeout(900);
    await p.screenshot({ path: `${out}/${name}.png`, ...(clip ? { clip } : {}) });
    console.log('saved', name);
  };
  const step = async (label, fn) => { try { await fn(); } catch (e) { failures.push(label); console.log('FAILED', label, e.message.split('\n')[0]); } };
  const api = (base, path, token, method = 'GET', body) => fetch(base + '/api' + path, {
    method, headers: { 'content-type': 'application/json', ...(token ? { authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  }).then(r => r.status === 204 ? null : r.text().then(t => t ? JSON.parse(t) : null));
  const demoLogin = (base, admin) => api(base, '/auth/demo-login', null, 'POST', { admin });

  // ---- a person on their phone ----
  await step('phone', async () => {
    const p = await open(DEMO, PHONE);
    await shot(p, 'phone-1-sign-in');
    await press(p, /What is this/);
    await shot(p, 'phone-1b-about-demo');
    await press(p, 'Got it');
    await press(p, 'Sign in with Microsoft');
    await shot(p, 'phone-2-documents');
    await p.getByRole('checkbox', { name: /Contract draft/ }).first().click({ force: true });
    await shot(p, 'phone-3-over-limit');
    await p.getByRole('checkbox', { name: /Contract draft/ }).first().click({ force: true });
    await p.getByText('Level 3 East').first().click({ force: true });
    await shot(p, 'phone-4-pick-printer');
    await p.getByText('Reception').first().click({ force: true });
    await p.waitForTimeout(800);
    await button(p, /^Print 2 documents/).click({ force: true });
    await p.waitForTimeout(2500);
    await shot(p, 'phone-5-printed');
  });

  // ---- the printer's own screen ----
  await step('panel', async () => {
    const admin = await demoLogin(DEMO, false);
    const printers = await api(DEMO, '/printers', admin.token);
    const reception = printers.find(x => x.name === 'Reception');
    const p = await open(`${DEMO}/?printer=${reception.id}`, PANEL);
    await shot(p, 'panel-1-sign-in');
    await press(p, 'Sign in with Microsoft');
    await shot(p, 'panel-2-documents');
    await p.getByRole('checkbox', { name: /Contract draft/ }).first().click({ force: true });
    await shot(p, 'panel-2b-over-limit');
    await p.getByRole('checkbox', { name: /Contract draft/ }).first().click({ force: true });
    await p.waitForTimeout(500);
    await press(p, /^Print$/);
    await p.waitForTimeout(1500);
    await shot(p, 'panel-3-printing');
  });

  // ---- the administrator ----
  await step('admin', async () => {
    const p = await open(DEMO, WIDE);
    await press(p, /Demo: sign in as administrator/);
    await p.waitForTimeout(1500);
    await shot(p, 'admin-1-overview', { x: 0, y: 0, width: 1280, height: 660 });
    await shot(p, 'admin-2-printers', { x: 24, y: 360, width: 1232, height: 300 });
    await shot(p, 'admin-3-people', { x: 24, y: 676, width: 1232, height: 500 });
    await shot(p, 'admin-4-jobs', { x: 24, y: 1188, width: 1232, height: 312 });
    await press(p, 'Add a printer');
    await shot(p, 'admin-5-add-printer');
    await p.keyboard.press('Escape');
    await p.waitForTimeout(500);
  });
  await step('admin-confirm', async () => {
    const p = await open(DEMO, WIDE);
    await press(p, /Demo: sign in as administrator/);
    // The first box is "New people start with", the second is "Give everyone".
    const field = p.getByRole('textbox').nth(1);
    await field.click({ force: true });
    await p.keyboard.type('75');
    await press(p, 'Apply to everyone');
    await shot(p, 'admin-6-apply-to-everyone');
  });

  // ---- setup that still has things to do ----
  await step('setup-todo', async () => {
    const admin = await demoLogin(DEMO, true);
    for (const x of await api(DEMO, '/printers', admin.token)) await api(DEMO, `/admin/printers/${x.id}`, admin.token, 'DELETE');
    const p = await open(`${DEMO}/#token=${admin.token}`, WIDE);
    await shot(p, 'setup-1-finish', { x: 0, y: 0, width: 1280, height: 520 });
  });
  await step('setup-address', async () => {
    const admin = await demoLogin(MIXED, true);
    const p = await open(`${MIXED}/#token=${admin.token}`, WIDE);
    await shot(p, 'setup-2-register-address', { x: 0, y: 0, width: 1280, height: 420 });
  });

  // ---- signing in with a work account ----
  await step('work-account', async () => {
    let p = await open(GOOGLE, PHONE);
    await shot(p, 'workspace-google-phone');
    p = await open(`${GOOGLE}/?printer=p1`, PANEL);
    await shot(p, 'workspace-google-panel');
    p = await open(MICROSOFT, PHONE);
    await shot(p, 'workspace-microsoft-phone');
    p = await open(MIXED, PHONE);
    await shot(p, 'workspace-with-demo');
    p = await open(`${GOOGLE}/#error=wrong_account`, PANEL);
    await shot(p, 'workspace-turned-away');
  });

  await browser.close();
  if (failures.length) { console.log('Steps that failed:', failures.join(', ')); process.exit(1); }
})();
