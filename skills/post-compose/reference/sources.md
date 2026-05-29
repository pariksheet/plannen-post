# Reference — sources (gather phase, run-flow step 3)

A **source** is anything that returns data, declared in `config.md` under `sources`
with a logical `name` and a `type`. Walk all sources; store each result keyed by
`name`. Resolve any `secret: NAME` to `profile.secrets.NAME` (or the env var it
names). On **any** failure (MCP not connected, tool error, non-2xx, timeout, parse
error, missing secret), capture `{source, error}` and continue — never abort.

| type | how to fulfill |
|---|---|
| `mcp` | Resolve `tool: server.name` to an available MCP tool — try `mcp__<server>__<name>` and the plugin form `mcp__plugin_<server>_<server>__<name>`; match whichever exists. Invoke with `args` (default `{}`). |
| `http` | `curl -sS --max-time 15 <url>` (inject the secret as header/param if `secret:` is set). `as: json` → parse to an object; otherwise keep as text. |
| `web-search` | Run `WebSearch` with `query`. Keep result titles + URLs for provenance. |
| `cli` | **Only if defined in the profile** (security rule). Run the profile's command, capture stdout. A config naming a `cli` source the profile doesn't define → skip with a warning. |
| `file` | Read the path (taken from the profile if machine-specific). |

**Runtime token.** `{{since_last_edition}}` inside a source's `args` is substituted
in run-flow step 1: the date of the newest `~/.post/memory/YYYY-MM-DD.html` becomes
`after:YYYY/MM/DD`; if memory is empty, `newer_than:1d`. (This makes Monday reach
back to Friday and covers skipped days.)

**Multiple sources per section.** A section may list `source: [a, b]` (e.g. weather
+ pollen) — gather each and merge in Pass 1.

`ai-intro` / `ai-outro` sections have no source — they are composed in Pass 1 from
everything gathered.
