# Reference — assembly & component kit (Pass 2, run-flow step 5)

Deterministic assembly. Read `${CLAUDE_PLUGIN_ROOT}/templates/<masthead.theme or
"newspaper">.html` (fall back to `newspaper.html` if the named theme is missing).
**Never write CSS** — the theme styles everything; you only fill slots.

## Per-section markup

Render each planned section as an `<article>` (omit blocks for absent fields):

```html
<article class="post-section post-section--<id>">
  <div class="kicker">{KICKER}</div>      <!-- omit for outro -->
  <h2 class="hand">{tagline}</h2>          <!-- omit if none -->
  <p class="byline">{byline}</p>           <!-- intro only, optional -->
  <hr class="dashed">                      <!-- omit for outro & weather -->
  <div class="body">{body_html}</div>
</article>
```

## Component → body markup

| component | render the body as |
|---|---|
| `card` | paragraphs in `<p>` |
| `list` | `<ul><li>` (CSS adds the arrow) |
| `stat` | `<div class="stat"><span class="num">N</span><span class="lbl">…</span></div>` |
| `quote` | `<blockquote class="pull">…</blockquote>` |
| `two-col` | `<div class="twocol"><div>…</div><div>…</div></div>` |
| `photo` | `<figure><img src="…"><figcaption>…</figcaption></figure>` |
| `sticky-note` | outro styling (set by `post-section--outro`) |

New info → a new section built **from existing components**, never new styles.

## Cross-ref note (Pass 1.5 correlations)

An event carrying `cross_refs[]` (from run-flow step 4.5) renders each entry as an
inline note **inside that event's own markup** — never as a separate section. Append
it to the event's body item, reusing existing styling (no new CSS):

```html
<li>Outdoor football · 18:00 <span class="pull">⚠ hail forecast for that window</span></li>
```

Use the `pull` emphasis (or a plain trailing clause) so the note reads as a heads-up
attached to the item, not a new line of its own. One note per event, max.

## Placement

Each template column renders as **one phone page** — `render-shot.js` starts a new
page at every column boundary. So placement is by column (= by page), not by
balancing height:

- **Left column — the day** (page 1): `<!-- {{events}} -->`, then
  `<!-- {{intro}} -->` (the lead), then `<!-- {{weather}} -->`.
- **Center column — the feeds** (page 2): every **dynamic** section, in config
  order, into `<!-- {{dynamic.center}} -->` (`sport`, `news`, `tech`, `startup`,
  `watches`, and any improvised dynamic section).
- **Right column — personal** (page 3): `<!-- {{inbox}} -->`, then
  `<!-- {{outro}} -->` (the sign-off).

- A slot with no matching/failed section → empty string. An empty **column** emits
  no page at all (e.g. a quiet day with no dynamic sections → 2 pages, not a blank
  middle one).
- Don't reshuffle sections across columns to even out height — the page identities
  (day / feeds / personal) matter more than equal page lengths. A long column just
  makes a taller page (or splits by height as a fallback).

## Masthead substitution

- `<!-- {{masthead.dateline}} -->` → `"{Day} · {DD} {Mon} · morning edition[ · for the {family}][ · {emoji} {temp}°C]"`. Drop the family clause if `masthead.family` is unset; drop the weather clause if no weather data. Emoji: ☀ clear, ⛅ partly cloudy, ☁ overcast, 🌧 rain, ❄ snow, 🌫 fog.
- `<!-- {{masthead.printed}} -->` → the printed time computed in step 1.

Write the rendered HTML to `/tmp/plannen-post-${TODAY}.html`.

## Plain-text digest (for text sinks)

Per section emit the `KICKER` as a heading, a blank line, then tagline-then-body;
join sections with `\n\n---\n\n`; prepend `THE PLANNEN POST — {Day DD Mon}`. For
the outro, emit the body only.
