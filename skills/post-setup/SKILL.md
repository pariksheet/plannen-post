---
name: post-setup
description: Interactive first-time setup for plannen-post. Use when the user runs `/plannen-post:setup`, asks to set up / configure / onboard the Post, or says "help me build my morning newspaper". Detects connected MCPs, walks the user through their sections conversationally, previews the edition, configures delivery, and offers to schedule.
allowed-tools: Read Write Bash WebSearch WebFetch
---

# post-setup

You are onboarding a new user to plannen-post **conversationally**. The goal is to
produce two files tailored to *this* user and *their* connected tools:

- `~/.post/config.md` — the portable content brief (logical names, no secrets)
- `~/.post/profile.yaml` — the machine-local bindings (keys, routing, must-watch,
  render capability, shell sinks)

This is an **interactive** flow. Ask, then **wait for the user's answer** before
moving on. Do not write the files until the user has signed off on a preview.
Honour the architecture in `${CLAUDE_PLUGIN_ROOT}/docs/ARCHITECTURE.md`, especially
the **intent-portable / bindings-local** split and the **security rule** (only the
profile may define `cli` sources or shell sinks).

If `~/.post/config.md` already exists, ask whether to reconfigure from scratch or
edit the existing one (`/plannen-post:post-config` opens it) before proceeding.

---

## Step 1 — Detect what's connected

Look at your own available tool list. Identify connected MCP servers useful for a
newspaper and bucket them:

- **Sources** (data in): mail (e.g. Gmail `search_threads`), calendar (Google
  Calendar `list_events`), a weather source (or none → use open-meteo over HTTP,
  keyless), plannen (`get_briefing_context`, `get_watch_queue`) if present, web
  search (always available), drive/files, etc.
- **Sinks** (delivery out): Gmail `create_draft`, a WhatsApp/Telegram notify tool,
  a printer MCP, etc.
- **Render**: check for a render MCP, or a local browser for PNG/PDF — run
  `command -v node` and look for Google Chrome / Chromium / Edge (the bundled
  `scripts/render-png.sh` works if both exist).

Show the user a short table: *what you found* and *what's missing* (and what the
absence means — e.g. "no weather MCP → I'll use open-meteo over HTTP"). Be honest
that anything not connected will be skipped or needs setup.

## Step 2 — About the user

This tailors voice and priorities. Ask:

- "**Do you have an `aboutme.md`** (or similar) I should read?" — if yes, read it.
- Otherwise: "Tell me about you — **name, who's in the picture, where you are, and
  anything you always want the paper to watch.**"
- **If a plannen MCP is connected**, offer: "I can pull your profile from plannen
  instead — want me to?" and use `get_profile_context` if they agree.

Keep what's relevant for the paper (location for weather, family for events,
interests for news/sport beats). Do **not** save any of it to your own memory.

## Step 3 — Walk the sections

Start from the standard spine — **intro · weather · events · inbox · outro** — and
go one at a time. For each, tell the user the default and ask how they want it in
their own words (source, location, what to emphasise). Examples of the kind of
answer to expect: *"weather for Berlin from open-meteo, and I'm allergic to pollen
so include pollen levels"* / *"inbox: only mail awaiting my reply"*.

Then ask what **extra** sections they want beyond the spine (sport, news by beat,
tech, finance, markets, …). These land in the **dynamic zone**, gated `when: present`.

**If the user asks for something the standard template has no slot for**, tell them:
it'll render in the dynamic zone using a component from the kit (`card`/`list`/
`stat`/`quote`/`two-col`/`photo`) — confirm which fits. Never invent new CSS.

For each section capture: a logical **source** (type + how to call it), the
**component**, the **slot** (spine/dynamic), and a **prose hint** (the editorial
steering, in their words). Remember the inbox two-bucket pattern (`inbox_new` +
`inbox_open` rail) if they want still-open threads — and that **must-watch senders
go in the profile, never the config**.

## Step 4 — Preview and sign off

Compose a **sample edition from today's real data** so the user can see it:
follow the `post-compose` skill's gather → Pass 1 → Pass 2 steps (steps 3–5 there),
but **stop before delivery**. Write the HTML to `/tmp/` and:

- If a render capability is available, render a PNG and open it
  (`open <file>` on macOS) so they see the real image.
- Otherwise open/show the HTML.

Show the run report (sections rendered / skipped). Ask for sign-off, and iterate on
section order, wording, or emphasis until they're happy. **Only now** write
`~/.post/config.md` (and stub `~/.post/profile.yaml`).

## Step 5 — Delivery

Offer only channels whose sink is reachable (or easily set up). For each, resolve
the binding into the **profile**, not the config:

- **Gmail draft** (universal, draft-only) — `to: self` defaults to the connected account.
- **WhatsApp / Telegram** — if a notify MCP is connected, no token needed; record
  any routing (chat id) in the profile. For the curl-Telegram fallback, note the
  `~/.zshenv` token caveat.
- **Format**: offer `png` only if a render capability exists; wire `profile.render`
  (prefer the local `scripts/render-png.sh` via `via: shell`). Otherwise default to
  `html` (Gmail) or `text`, and set the delivery `else:` fallback.

Write the resolved sinks + render + any secrets/must-watch into `~/.post/profile.yaml`.
**Never put a secret, chat id, recipient, or shell command into `config.md`.**

## Step 6 — Offer to schedule

Ask if they want it to run automatically. If yes, offer:

- **Claude Code `/schedule`** — simplest: tell them to run, e.g.
  `/schedule "daily at 07:00 <their tz>: /plannen-post:post"`.
- **macOS launchd** (for "run at 06:00, and if the Mac was off, catch up on boot") —
  generate a LaunchAgent from `scripts/`: substitute the real **repo path** and
  **node path** (`dirname $(command -v node)`) into a plist at
  `~/Library/LaunchAgents/work.plannen-post.daily.plist` using
  `${CLAUDE_PLUGIN_ROOT}/scripts/post-wrapper.sh`, with `StartCalendarInterval` at
  their chosen time and `RunAtLoad` for boot/wake catch-up. Load it with
  `launchctl bootstrap gui/$(id -u) <plist>` and confirm with `launchctl print`.
  The wrapper's per-day guard prevents duplicate editions.

## Step 7 — Done

Summarise: which sections, which delivery, the schedule (if any), and the two file
paths. Tell them `/plannen-post:post` runs it anytime and
`/plannen-post:post-config` reopens the config.

---

## Rules

- **Interactive.** Ask and wait; don't assume answers. The user drives content.
- **Two-layer discipline.** Intent → `config.md`; bindings/secrets/shell → `profile.yaml`. A config you write must be safe to share.
- **Capability honesty.** Only offer what's actually reachable; say plainly what's missing and what it costs.
- **No writing before sign-off.** Preview first.
- **Don't persist user facts to your own memory.** They live in plannen/aboutme/the profile.
- **Security.** Only the profile may define `cli` sources or shell sinks/render.
