# The Plannen Post on n8n

A working port of the Post to **[n8n](https://n8n.io)** — same idea, different orchestrator. The Claude Code plugin runs the whole pipeline inside one agent session; this version lets **n8n** do the orchestration (schedule, fan-out, fan-in, delivery) and keeps an **LLM as the brain** for the one step that needs judgment: writing the edition.

> This is a reference implementation, not a supported product. It mirrors [`examples/config.pari.example.md`](../../examples/config.pari.example.md) — the maintainer's real setup — as an n8n graph. Import it, swap in your own credentials and endpoints, and adjust.

## The split

- **n8n orchestrates** — a 06:30 schedule, parallel source fetches, a merge, JSON assembly, the Gmail draft, and memory read/write.
- **The LLM composes** — a single **AI Agent** node (an Anthropic chat model) gets all the gathered data plus the editorial brief as its system prompt, calls a few read-only tools, and returns the structured edition as JSON. Same two-pass editorial judgment as the plugin, expressed as one prompt.

Nothing about the *content* lives in n8n logic — the brief is the agent's system message, exactly like the plugin's section hints.

## Flow

```
Daily 06:30 ─┬─ Fetch Recent Mail ─ Aggregate Mail ─────────────┐
             ├─ Fetch Weather (5 models) ─ Fetch Pollen ─ Digest ┤
             ├─ Read Memory ──────────────────────────────────────┤
             └─ Fetch Sent Mail ─ Aggregate Sent ─────────────────┤
                                                                   │
                                          Join Sources ◀───────────┘
                                                │
                          Compose Edition (AI Agent ⟵ Plannen MCP, Web Search)
                                                │
                          Assemble Edition (extract JSON → html + pages[])
                                          ├─────────────────┐
                                  Split Pages          Write Memory
                                          │
                          Render PNG → Fetch PNG → Collect Pages
                                          │
                                  Create Gmail Draft (HTML + page PNGs)
```

## How it maps to the plugin

| Plugin concept | n8n equivalent |
|---|---|
| `sources:` (gather, failure-isolated) | parallel branches → **Join Sources** (merge) |
| `gmail.search_threads` (3 inbox buckets) | **Fetch Recent / Sent Mail** + **Aggregate** nodes |
| weather/pollen HTTP + multi-model consensus | **Fetch Weather** (5 `models=`) → **Digest Weather** (Code: median per hour) |
| plannen MCP (`get_briefing_context`, `get_watch_queue`, …) | **Plannen MCP** tool node, attached to the agent |
| web-search beats (sport/news/tech/startup) | **Web Search** HTTP tool (Tavily), attached to the agent |
| Pass 1 / 1.5 / 2 editorial compose | **Compose Edition** agent system prompt → **Assemble Edition** Code node |
| rolling 7-day memory sidecars | **Read Memory** / **Write Memory** (n8n Data Table, keyed on `edition_date`) |
| WhatsApp PNG delivery | **Render PNG** (HTML→image) → **Create Gmail Draft** with page attachments |

## Setup

1. **Import** `plannen-post.workflow.json` into n8n (*Workflows → Import from File*). Credentials are **not** included in the export — you attach your own.

2. **Attach credentials** to these nodes:
   - **Claude** (`lmChatAnthropic`) — an Anthropic API key. The export ships `claude-sonnet-4-6`; switch the model to whatever you prefer.
   - **Fetch Recent / Sent Mail**, **Create Gmail Draft** — your Gmail OAuth2.
   - **Plannen MCP** — Bearer Auth. Replace the placeholder endpoint `https://YOUR-PLANNEN-PROJECT.supabase.co/functions/v1/mcp` with your plannen **Tier-2** MCP URL, and bind the bearer token. (Tier-2 = plannen's MCP exposed as a Supabase Edge Function over HTTP; Tiers 0–1 are stdio-only and unreachable from n8n Cloud.)
   - **Web Search** — Bearer Auth with a [Tavily](https://tavily.com) key (free tier is enough).
   - **Render PNG** — Bearer Auth with an [HCTI](https://htmlcsstoimage.com) key (HTML→image). n8n Cloud has no native render node; this is the stand-in.

3. **Create the memory Data Table** — a table with at least an `edition_date` column (plus a column for the carryover JSON). Point **Read Memory** / **Write Memory** at it.

4. **Set your location** in **Fetch Weather** / **Fetch Pollen** (lat/long) and your **beats** in the **Web Search** queries — the export carries the maintainer's (Mechelen; Databricks/IPL/VRT).

5. **Edit the brief** — the editorial rules live in the **Compose Edition** node's system message. That's the equivalent of the plugin's per-section prose hints; tune tone and selection there.

## Gotchas (learned the hard way)

- **Agent iterations** — the agent calls ~9 tools sequentially (plannen + web), so `maxIterations` must be generous (this export uses **12**). Too low → *"Max iterations reached"* or a blank edition.
- **No output parser** — the agent returns reasoning text *plus* JSON. **Assemble Edition** extracts the edition by **brace-matching from the end** (taking the last balanced object with `.sections`). A naive first-`{`-to-last-`}` grab catches stray braces in the reasoning and yields a blank edition.
- **Cross-branch references after a merge** — read merged sibling branches with `$("Node").first().json`, not `$("Node").item` (which can come back empty after an append-style fan-in).
- **Bearer auth on HTTP tool nodes** — you must select the credential in the UI. A name-only credential stub throws *"Found credential with no ID."*
- **HCTI** — `viewport_height` is required whenever `viewport_width` is set.
- **Attachment names** — **Collect Pages** sets each binary's `fileName`/`fileExtension`/`mimeType` so the draft attaches `post-1.png … post-N.png` with real extensions.
- **n8n Cloud API lag** — execution/status endpoints can lag minutes; verify a run by reading the resulting Gmail draft, not the execution list.

## Differences from the plugin

- **Delivery** is a **Gmail draft with page PNGs** — there's no WhatsApp sink on n8n Cloud (would need a cloud WhatsApp provider) and the render is an external HTML→image service rather than the plugin's local renderer.
- **Memory** is a Data Table row, not HTML + JSON sidecars on disk; there's no automatic 7-day prune.
- Everything personal (endpoint, location, beats, credentials) is yours to fill — this export carries **no secrets** and only the location/beats that are already public in `config.pari.example.md`.
