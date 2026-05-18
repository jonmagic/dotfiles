# Agent Instructions

This repository contains jonmagic's personal dotfiles. Keep changes small,
practical, and focused on the requested behavior.

## Repo layout

- `README.md` documents installation and the terminal help experience.
- `bin/` contains executable scripts, including `bin/help`.
- `sources/aliases` defines shell aliases.
- `sources/functions.zsh` defines user-facing shell functions.
- `sources/entrypoint` wires startup behavior for interactive terminals.
- `.github/skills/dotfiles-help/SKILL.md` contains the detailed workflow for
  maintaining the generated terminal help.

## Terminal help changes

Use the `dotfiles-help` skill before changing aliases, user-facing functions,
executable scripts in `bin/`, or startup help wiring.

For help-related edits:

1. Inspect `bin/help`, `sources/aliases`, `sources/functions.zsh`, `bin/`, and
   `sources/entrypoint` before editing.
2. Treat those files as the source of truth. Prefer deriving help text from
   nearby comments instead of maintaining a separate registry.
3. Keep the startup hook local-session only and preserve the nested-shell guard
   so the guide prints once per terminal.
4. Validate with:

```bash
bash -n bin/help bin/update-software
zsh -n sources/entrypoint sources/aliases
DOTFILES_HELP_DISABLE=1 bin/help --plain
```

## Commit hygiene

- Do not commit secrets, machine-local credentials, or generated temporary
  files.
- Preserve unrelated user changes in the working tree.
- Use concise conventional commit messages for code and documentation changes.
