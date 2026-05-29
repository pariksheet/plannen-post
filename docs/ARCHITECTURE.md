# plannen-post — Architecture (v2 design)

**Status:** Draft / agreed direction
**Supersedes:** the v1 implementation (`skills/post-compose/SKILL.md`, single `config.yaml`)

A Claude Code plugin that composes a personalised "newspaper" from data the user
can already reach, renders it into a styled HTML edition, and delivers it to one
or more channels in the user's chosen format. Stateless compute plus a rolling
7-day local working memory, a single portable config file, no database, no server.

---

## 1. Goals & non-goals

### Goals
- **Pluggable inputs.** A source is *anything the user can reach* — MCP tool, web
  search, HTTP endpoint, CLI command, file read.
- **User-authored content.** The user describes what their paper should contain
  in a human-readable config — which sources feed which sections, what to
  emphasise, where it goes and in what format.
- **Reliable, attractive output.** A fixed, email-safe visual spine plus room for
  the day's surprises, assembled from a known component kit — never broken layout.
- **Pluggable, capability-gated delivery.** Any sink that accepts content: email,
  Telegram, WhatsApp, a printer MCP, a file. Formats (HTML / PDF / PNG / …) are
  opt-in by capability, not hardcoded.
- **Easy to distribute and adopt.** A config is a portable file you can share.
  Setup introspects your connected MCPs and scaffolds the rest.

### Non-goals (v2)
- No database, no web service, no hosted backend. Channels are the *permanent*
  archive; the only local state is a bounded, rolling 7-day working memory (§9a)
  — a cache, not a datastore.
- No bundled heavyweight renderers (chromium, etc.). Rendering to PDF/PNG is a
  *connected capability*, not a shipped dependency.
- No auto-send of irreversible actions without the user's channel config saying so.
- No multi-user. One user, one (or more) configs on one machine.

---

## 2. Core principles

1. **A source is anything that returns data; a sink is anything that accepts
   content.** Symmetric abstractions at the two ends of the pipeline.
2. **Declare structure, prompt for judgment.** The config declares *which*
   sections/sources/sinks exist (deterministic); prose hints steer *tone and
   selection* (fuzzy).
3. **Fill slots, don't invent layout.** The LLM chooses components and content;
   a deterministic pass assembles HTML. The model never hand-writes CSS.
4. **Intent is portable; bindings are local.** The shared config names things
   logically. A machine-only profile resolves them to real accounts, keys, and
   devices. A downloaded config can never run a command or leak a secret.
5. **Connected MCP = no binding needed.** MCP servers own their own auth and
   identity. The more the user does via MCP, the closer the local profile gets to
   empty.
6. **Capability-gated with graceful degradation.** Probe a capability; use it if
   present; otherwise fall back per a declared order and warn. Tomorrow's edition
   is the retry.
7. **Short, bounded memory — not a database.** Each edition is persisted as a
   rendered artifact plus a structured sidecar, kept for the last 7 editions only
   (§9a). Memory exists for *continuity* (dedup, callbacks, escalation), never as a
   queryable store. Local-only, never shared.

---

## 3. Pipeline

```
sources ─▶ config ─▶ html template ─▶ rendering ─▶ delivery
(data in)  (intent)   (theme + kit)   (compose +    (sinks,
                                  ▲    assemble)     formats)
                                  │         │
                         working memory ◀───┘
                         (last 7 editions: HTML + JSON sidecar)
                         read for continuity · written each run
```

| Stage | What it is |
|---|---|
| **sources** | Anything reachable: MCP tool, web search, HTTP, CLI, file read. |
| **config** | Human-readable file: what goes in the paper, which source/API per section, delivery channel + format. The portable, shareable unit. |
| **html template** | Fixed presentation spec (the *theme*): a styled spine + a component kit. Email-safe. |
| **rendering** | LLM reads config, gathers source data, fits it into the spine, improvises new sections into the dynamic zone when warranted — by emitting a structured plan, not raw HTML. |
| **delivery** | Hands the edition to each configured sink in the requested format, gated by capability, degrading on absence. |

---

## 4. Sources (data in)

A source is a typed connector. Known types:

| type | how it's fulfilled | auth / binding |
|---|---|---|
| `mcp` | invoke an MCP tool by logical name + args | handled by the connected MCP server — **no local secret** |
| `http` | fetch a URL (text/json) | API key, if any, lives in the local profile |
| `web-search` | a search query, results summarised | via the connected search capability |
| `cli` | run a shell command, capture stdout | **local profile only** (see security) |
| `file` | read a local file | path in local profile if machine-specific |

**Per-source failure isolation (unchanged from v1):** if a source is not
connected, errors, or times out, that section is skipped and reported. The run
continues.

---

## 5. Config (the portable content brief)

A human-readable file (markdown with light structured frontmatter). It declares:

- **sections** — the spine sections plus any standing dynamic-zone sections.
- **sources** — by *logical name*, with the API/tool/query to call and a free-form
  **prose hint** steering selection and tone ("pick the 3 threads worth knowing,
  skip newsletters").
- **delivery** — channel + format intent, by logical sink name, with a fallback
  chain.

It contains **no secrets, no personal identifiers, no machine paths, no shell
commands.** That is what makes it shareable: someone can hand you their
"finance-nerd morning brief" config and you run it against *your* bindings.

> **Structured skeleton + prose body.** The frontmatter is deterministic enough to
> debug ("why did sport vanish?"); the prose is expressive enough to capture
> editorial taste. We deliberately do **not** go full free-prose — that trades
> away reproducibility.

---

## 6. HTML template (theme + component kit)

The theme is a **fixed visual spec**, designed **email-safe** (table layout,
inline styles, no reliance on flexbox/grid/web-fonts surviving Gmail). It provides:

- **A fixed spine** — always-present named slots: `intro`, `weather`, `events`,
  `inbox`, `outro`, … The predictable skeleton.
- **A dynamic zone** — where improvised sections land.
- **A component kit** — a small set of pre-styled, email-safe building blocks the
  renderer composes from:

  | component | use |
  |---|---|
  | `card` | a titled block of prose/bullets |
  | `list` | arrowed line items (events, todos) |
  | `sticky-note` | the yellow outro note |
  | `stat` | a single number + label |
  | `quote` | a pulled quote / highlight |
  | `two-col` | side-by-side blocks |
  | `photo` | an image with caption |

The model may introduce a brand-new section (e.g. a `SPORT` card the day tennis
news appears) **using only components that already exist** — so new information
yields a new section without a single new line of CSS, and the edition never
renders broken.

> A user may swap the theme by name. Themes are presentation only; configs are
> content only. Neither rewrites the other.

---

## 7. Rendering (two passes)

The crux of the design. Rendering separates **fuzzy editorial judgment** from
**deterministic assembly**:

```
PASS 1 — editorial judgment (LLM):
  • read config + gathered source data
  • write prose per section under its hint (≤ limits, factual, no marketing)
  • decide the lead / ordering by importance
  • improvise dynamic-zone sections when new info warrants
  • read the previous edition's sidecar from working memory (§9a) for
    continuity — what was surfaced before, what's still open
  • OUTPUT: a structured section-plan, e.g.
      [{ id: sport, component: card, slot: dynamic,
         kicker: "SPORT", body: "...", }, ...]
    plus masthead variables (dateline, issue no., printed time)
    This plan IS the sidecar persisted to working memory (§9a) — free reuse.

PASS 2 — assembly (deterministic, no LLM):
  • for each planned section, render its component's HTML with inline styles
  • drop into the named slot, or append to the dynamic zone
  • substitute masthead variables
  • unfilled slots collapse cleanly
  • OUTPUT: the final edition (HTML), plus a plain-text digest for text sinks
```

The model's creativity is bounded to *"which component, what content, where."*
HTML stays boring and safe. Layout can't drift or break.

---

## 8. Delivery (sinks, formats, capability-gating)

A sink is anything that accepts content. A delivery entry is a *(sink, format,
fallback)* triple, named logically and resolved by the local profile:

```yaml
deliver:
  - to: gmail          # logical sink → resolved locally
    format: html       # email renders HTML natively; default
  - to: whatsapp
    format: png
    else: html-link    # if no render capability present, send a link instead
  - to: printer
    format: pdf
    else: skip
```

**Format as a capability.** HTML is free (always available). PDF/PNG require a
**connected render capability** (ideally an `html → {pdf,png}` MCP — *not* a
bundled chromium). The pipeline gains an optional **render transform** between
compose and sink:

```
compose ─▶ [render transform?] ─▶ sink
```

**Compatibility = attempt-and-degrade.** We do not maintain a format↔sink matrix.
We attempt the requested format; on missing capability we walk the `else:` chain
and warn. A tiny built-in hint table covers the common channels (email→html,
telegram→text/photo/document, whatsapp→image/document, printer→pdf).

**Prefer MCP sinks over raw curl.** An MCP sink carries its own auth, which
removes binding from the local profile and dodges the v1 `TELEGRAM_BOT_TOKEN`
footgun entirely.

---

## 9. Local profile (machine-only bindings)

Never shared. Holds only what the connected MCPs don't already provide:

| Holds | Why it can't be in the shared config |
|---|---|
| **personal routing** — chat_id, printer name, recipient address | personal, would leak |
| **non-MCP secrets** — raw HTTP API keys (finance/news) | secret, no MCP to hold them |
| **shell sink / `cli` source definitions** | security: a downloaded config must never run a command |

**Net rule:** *Connected MCP → no binding needed (auth + identity handled). Local
profile only holds personal routing, non-MCP secrets, and shell definitions.* In
an all-MCP setup the profile can be nearly empty — perhaps just a chat_id, and
even that can default (a draft "to self" uses the connected account's own
address).

### Security rule (load-bearing)
Only the **local profile** may define a `cli` source or a shell sink. A shared
config can reference them by logical name but can never *introduce* one. This is
what makes running a stranger's config safe.

---

## 9a. Working memory (rolling 7-day)

A bounded local cache that gives the paper continuity without becoming a database.
Local-only, never shared (same trust class as the profile).

**Layout** — two files per edition, dated:

```
~/.post/memory/
  2026-05-29.html     ← rendered edition (human artifact / local archive)
  2026-05-29.json     ← structured sidecar (machine memory) = the Pass-1 plan
  2026-05-28.html
  2026-05-28.json
  …                   ← keep the last 7 editions; prune older on each run
```

**The sidecar is the Pass-1 section-plan** (§7) plus a few continuity facts — we
get it for free, no extra LLM work. It exists so the next morning's render can
reason precisely instead of re-parsing yesterday's HTML. Illustrative shape:

```json
{
  "date": "2026-05-29",
  "weather": { "headline": "Rain", "pollen_grass": "high" },
  "inbox_surfaced": ["thread_id_a", "thread_id_b"],
  "open_items": [{ "thread_id": "x", "who": "Silvia (EC)", "shown_count": 3 }]
}
```

**What it buys**
- **Exact look-back windows.** A source's "since last edition" resolves to the
  date of the newest file in `memory/` — so Monday automatically reaches back to
  Friday, and a skipped day is covered. No schedule-guessing.
- **Dedup + escalation.** Knowing a thread was surfaced N times and is still open
  lets the paper stop repeating once acted on, or escalate ("3rd day waiting"),
  instead of dumbly re-listing.
- **Callbacks / trends.** "Third day of high grass pollen," "yesterday's rain
  clears by noon."

**Bounds (deliberate)**
- Last **7 editions**, rolling; older files pruned each run.
- A *cache*, not a queryable store — read the most recent 1–7 sidecars for
  continuity, nothing more.
- Local-only; never shared, never part of the portable config.
- The permanent human archive is still the delivery **channels** — memory is
  short-term working context, not the record of record.

---

## 10. Setup & onboarding

Skills/plugins have no executable install hook, so onboarding is a
**user-triggered command** (`/plannen-post:setup`) that:

1. **Introspects the live tool list** — sees which `mcp__*` tools are connected.
2. **Proposes sections** for what it found ("you have Gmail, plannen, a weather
   source — want a section for each?").
3. **Scaffolds a starter config** from a bundled base template.
4. **Collects the minimal local bindings** still required (e.g. a chat_id).
5. **Offers to schedule** the daily run.

First run with no config behaves like v1: bootstrap from the base, open for
editing, exit cleanly with "edit, then run again."

---

## 11. Scheduling

No scheduler ships in the plugin. Wire it via Claude Code's `/schedule`:

```
/schedule "weekdays at 07:00 Europe/Brussels: /plannen-post:post"
```

The routine inherits MCP servers and shell env captured at schedule time.
Migrating delivery to MCP sinks removes the non-interactive-shell env-var
fragility that v1's curl+token delivery suffers from.

---

## 12. Deferred / open

- **PDF/PNG render capability:** ship as a documented "connect a render MCP" path;
  graceful `else:` degradation until one is present.
- **WhatsApp/Telegram as *input*:** reading a group chat to digest it needs
  read-capable access the current send-only `whatsapp-notify` doesn't provide.
  Different (harder) integration than delivery; revisit.
- **Long-horizon recall ("on this day last year"):** the 7-day working memory
  (§9a) now covers short-term continuity. True long-range callbacks would need a
  longer or compressed history (or reading past editions back from the channel
  archive) — still deferred; out of scope for the rolling cache.
- **Sink format negotiation:** if sinks ever expose accepted formats via their MCP
  schema, we can replace attempt-and-degrade with a declared check.

---

## 13. Migration from v1

| v1 | v2 |
|---|---|
| single `~/.post/config.yaml` mixing intent + bindings | **config** (portable intent) + **local profile** (bindings) |
| `mcp-call` / `http-fetch` section kinds | generalised **sources** (mcp/http/web-search/cli/file) |
| fixed template slots only | **fixed spine + dynamic zone + component kit** |
| model fills slots | **two-pass render**: editorial plan → deterministic assembly |
| gmail draft + telegram (curl+token) | **capability-gated sinks**, MCP-preferred, format fallbacks |
| compose in one prose pass | judgment/assembly separated for reliability |
| stateless, channels are the only archive | + **rolling 7-day working memory** (HTML + JSON sidecar) for continuity |
