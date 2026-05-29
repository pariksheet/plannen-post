// Render an HTML file to a full-page PNG using a local Chrome via puppeteer-core.
// Invoked by render-png.sh, which sets CHROME_PATH and NODE_PATH.
// Usage: node render-shot.js <input.html> <output.png>
const path = require('path');
const puppeteer = require('puppeteer-core');

const [, , input, output] = process.argv;
if (!input || !output) {
  console.error('usage: render-shot.js <input.html> <output.png>');
  process.exit(2);
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: process.env.CHROME_PATH,
    headless: 'new',
    args: ['--no-sandbox', '--hide-scrollbars'],
  });
  const page = await browser.newPage();
  // ~820px width trips the template's <900px media query → clean single-column,
  // phone-friendly tall image. 2x for crisp text.
  await page.setViewport({ width: 820, height: 1200, deviceScaleFactor: 2 });
  await page.goto('file://' + path.resolve(input), { waitUntil: 'networkidle0' });
  await page.screenshot({ path: output, fullPage: true });
  await browser.close();
  console.log('rendered ' + output);
})().catch((e) => {
  console.error('render failed:', e.message);
  process.exit(1);
});
