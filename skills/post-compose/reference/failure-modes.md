# Reference — failure modes

Per-section and per-channel failures **never abort the run** — capture and report.

- **`~/.post/config.md` missing** → first-run flow (step 0), exit cleanly.
- **Malformed config frontmatter** → print the first parse error verbatim, exit. Do not repair.
- **A source fails** (not connected / errors / times out / parse fails / missing secret) → skip its section(s), record the warning, continue.
- **All sources fail** → still compose a minimal `intro` + `outro` from an empty set ("quiet morning this morning") and deliver that, flagged as a Post-with-warnings.
- **A format isn't renderable** (no `profile.render`) → take the delivery entry's `else:` chain and warn.
- **A sink is unreachable / unresolved** (no matching profile sink, or a required token unset) → skip that channel, keep the others.
- **No delivery channel works at all** → the HTML at `/tmp/plannen-post-*.html` and `~/.post/memory/` is the recovery artifact; exit non-zero with the errors printed.
- **A `cli` source or shell sink referenced by the config but not defined in the profile** → skip it with a warning (security rule; the config can't introduce commands).
