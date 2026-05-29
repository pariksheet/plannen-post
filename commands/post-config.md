---
name: post-config
description: Open the plannen-post config file (~/.post/config.yaml) in $EDITOR. Creates it from the example on first run.
argument-hint: ""
---

Open the plannen-post config for editing.

1. If `~/.post/config.yaml` does not exist:
   - Create `~/.post/` if needed: `mkdir -p ~/.post`
   - Copy the example from this plugin's `config.example.yaml` (located at the plugin root — one level above `commands/`) to `~/.post/config.yaml`.
   - Print: "Created ~/.post/config.yaml from the example. Opening editor — fill in your details and save."

2. Open it in the user's editor:
   ```bash
   ${EDITOR:-vi} ~/.post/config.yaml
   ```

3. After the editor exits, do **not** validate. The next `/plannen-post:post` run will fail loudly on malformed YAML.

Do not read the file's contents back to the user — the config may contain identifiers the user does not want echoed into the transcript.
