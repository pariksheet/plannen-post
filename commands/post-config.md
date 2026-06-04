---
name: post-config
description: Open the plannen-post config (~/.post/config.md) in $EDITOR. Creates config.md + profile.yaml from the examples on first run.
argument-hint: ""
---

Open the plannen-post config for editing.

1. If `~/.post/config.md` does not exist:
   - Create `~/.post/` if needed: `mkdir -p ~/.post`
   - Copy the examples from this plugin into place:
     - `${CLAUDE_PLUGIN_ROOT}/examples/config.example.md` → `~/.post/config.md`
     - `${CLAUDE_PLUGIN_ROOT}/examples/profile.example.yaml` → `~/.post/profile.yaml` (only if it doesn't already exist)
   - Print: "Created ~/.post/config.md (and profile.yaml) from the examples. Opening the editor — fill in your details and save."

2. Open the config in the user's editor:
   ```bash
   ${EDITOR:-vi} ~/.post/config.md
   ```

3. After the editor exits, do **not** validate. The next `/post` run will fail loudly on malformed frontmatter.

Remember the split: `config.md` is the portable content brief (no secrets);
`profile.yaml` holds the machine-local bindings (keys, chat ids, must-watch
senders, render capability). Do not read either file's contents back to the user
— they may contain identifiers the user does not want echoed into the transcript.
