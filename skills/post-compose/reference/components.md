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

## Placement

- **Spine** sections → their named slot: replace `<!-- {{<id>}} -->`
  (`intro`, `weather`, `events`, `inbox`, `outro`).
- **Dynamic** sections → flow into the dynamic zone to balance columns: fill
  `<!-- {{dynamic.left}} -->` and `<!-- {{dynamic.center}} -->` first (and
  `<!-- {{dynamic.right}} -->` only if needed), appending each to whichever
  marker's column is currently **shortest** by rough rendered height. Never leave
  one column long and another empty.
- A slot with no matching/failed section → empty string; the column collapses.

## Masthead substitution

- `<!-- {{masthead.dateline}} -->` → `"{Day} · {DD} {Mon} · morning edition[ · for the {family}][ · {emoji} {temp}°C]"`. Drop the family clause if `masthead.family` is unset; drop the weather clause if no weather data. Emoji: ☀ clear, ⛅ partly cloudy, ☁ overcast, 🌧 rain, ❄ snow, 🌫 fog.
- `<!-- {{masthead.printed}} -->` → the printed time computed in step 1.

Write the rendered HTML to `/tmp/plannen-post-${TODAY}.html`.

## Plain-text digest (for text sinks)

Per section emit the `KICKER` as a heading, a blank line, then tagline-then-body;
join sections with `\n\n---\n\n`; prepend `THE PLANNEN POST — {Day DD Mon}`. For
the outro, emit the body only.
