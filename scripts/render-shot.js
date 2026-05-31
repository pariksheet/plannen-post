// Render an HTML edition to phone-shaped PNG *pages* using a local Chrome via
// puppeteer-core. Invoked by render-png.sh, which sets CHROME_PATH and NODE_PATH.
//
// Usage: node render-shot.js <input.html> <output.png>
//
// Why pages: WhatsApp (and most chat sinks) accept images only and preview them
// inline. A single full-page screenshot of a long edition becomes a tall, narrow
// sliver that the phone downscales until the text is unreadable. Instead we render
// at phone width and slice the edition into portrait pages broken at section
// boundaries — each page arrives ~1:1 on a phone with large, legible text.
//
// Output contract: prints one absolute PNG path per line to STDOUT, in reading
// order. If the edition fits one page, that single file is written to <output>
// unchanged (backward compatible); otherwise pages are written as
// <base>-1.png, <base>-2.png, … next to <output>. Callers send each line as a
// separate image.
const path = require('path');
const puppeteer = require('puppeteer-core');

const [, , input, output] = process.argv;
if (!input || !output) {
  console.error('usage: render-shot.js <input.html> <output.png>');
  process.exit(2);
}

// Phone-shaped render geometry (CSS px; physical = ×deviceScaleFactor).
const WIDTH = 620;        // <900 trips the template's single-column media query; ≈1:1 on a phone at 2x
const MAX_PAGE_H = 1040;  // cap per page → portrait pages (~1240×2080 physical), not one long sliver
const SCALE = 2;          // crisp text on hi-dpi screens

function pagePath(p, total) {
  if (total === 1) return output;
  const dir = path.dirname(output);
  const ext = path.extname(output);
  const base = path.basename(output, ext);
  return path.join(dir, `${base}-${p + 1}${ext}`);
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: process.env.CHROME_PATH,
    headless: 'new',
    args: ['--no-sandbox', '--hide-scrollbars'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: WIDTH, height: MAX_PAGE_H, deviceScaleFactor: SCALE });
  await page.goto('file://' + path.resolve(input), { waitUntil: 'networkidle0' });

  // Measure break candidates: the top edge of each major block. We only ever cut
  // *between* blocks, never through one.
  const { fullHeight, bounds } = await page.evaluate(() => {
    const nodes = [...document.querySelectorAll('.masthead, .post-section, .footer')];
    const bounds = nodes.map((n) => {
      const r = n.getBoundingClientRect();
      return { top: r.top + window.scrollY, bottom: r.bottom + window.scrollY };
    });
    return { fullHeight: document.body.scrollHeight, bounds };
  });

  // Greedy pack blocks into pages no taller than MAX_PAGE_H, breaking before any
  // block that would overflow the current page. A block taller than a page gets
  // its own (over-tall) page rather than being split.
  const pages = [];
  let start = 0;
  let lastBottom = 0;
  for (const b of bounds) {
    if (b.bottom - start > MAX_PAGE_H && lastBottom > start) {
      pages.push([start, lastBottom]);
      start = lastBottom;
    }
    lastBottom = Math.max(lastBottom, b.bottom);
  }
  pages.push([start, fullHeight]);

  for (let p = 0; p < pages.length; p++) {
    const [y0, y1] = pages[p];
    const out = pagePath(p, pages.length);
    await page.screenshot({
      path: out,
      clip: { x: 0, y: y0, width: WIDTH, height: Math.ceil(y1 - y0) },
    });
    process.stdout.write(out + '\n'); // one page path per line, reading order
  }

  await browser.close();
  console.error(`rendered ${pages.length} page(s)`);
})().catch((e) => {
  console.error('render failed:', e.message);
  process.exit(1);
});
