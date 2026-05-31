# Reference — delivery (sinks, run-flow step 7)

For each `deliver` entry (a `{to, format, else?}` triple), resolve `to` to
`profile.sinks.<to>` and dispatch **independently** — one channel failing never
blocks another. On a missing capability, walk the `else:` chain and warn.

## Format gating

- `html` is always available.
- `png` / `pdf` require `profile.render` — a render capability: a render MCP, or a
  local shell renderer such as `scripts/render-png.sh`. To produce the asset, run
  the render capability with `{in}` = the `/tmp` HTML edition and `{out}` = a `/tmp`
  image path (for `via: shell`, substitute `{in}` / `{out}` / `{format}` into the
  command and run it).
- **A `png` render may emit several *page* files.** Chat sinks accept images only
  and preview them inline, so the bundled renderer slices a long edition into
  phone-shaped portrait pages and **prints one absolute path per line to stdout, in
  reading order**. Treat that line list as the asset: a single line → one image; N
  lines → N pages to send in order. (A one-page edition still writes the exact
  `{out}` you passed, so nothing changes for short editions.)
- If a format is requested but no render capability exists → take `else:`
  (e.g. `text`, `html-link`, `skip`) and record a warning.

## Sink dispatch by `via`

- **`via: mcp`** → call the named MCP tool.
  - **Gmail (`gmail.create_draft`) is draft-only — never send.**
  - For an **image** format on an image-capable sink (e.g.
    `whatsapp-notify.send_notification`), pass each rendered page (one stdout line
    each) as the tool's image parameter (`imagePath`) in **separate calls, in
    order**. Caption only the **first** page with the masthead line plus a page
    count when there is more than one (e.g. `THE PLANNEN POST — Sun 31 May · 1/3`);
    later pages get a bare `n/N` caption so the chat isn't repetitive. Report the
    message id of each page sent.
  - For **text** format, send the plain-text digest (chunk to ≤4000 chars on `---`
    boundaries for chat sinks).
- **`via: http`** → curl (e.g. legacy Telegram `sendMessage` with `${env:TOKEN}`).
  If a required env var/token is unset, capture "skipped: <VAR> not set" and continue.
- **`via: shell`** → run the profile's command with `{file}` / `{format}`
  substituted. **Shell sinks are valid only when defined in the profile** — never
  run a shell command a config introduced.
- A `to:` the profile doesn't resolve → skip with a warning.

Capture each channel's result (draft id, messages sent, file path, or skip reason)
for the run report.

## Security (load-bearing)

Only the **local profile** may define `cli` sources or shell sinks/render. A
downloaded config can reference them by logical name but can never *introduce* a
command — this is what makes running a stranger's config safe.
