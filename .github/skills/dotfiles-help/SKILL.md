---
name: dotfiles-help
description: Maintains the generated terminal help in this dotfiles repo. Use it when aliases, functions, scripts, or startup wiring change.
---

# Dotfiles Help

## Overview

This skill maintains the generated terminal command guide for `jonmagic/dotfiles`.

The help experience is driven by:

- `bin/help`
- `sources/aliases`
- `sources/functions.zsh`
- executable scripts in `bin/`
- the startup hook in `sources/entrypoint`

## When to Use

Use this skill when you are:

- adding, removing, or renaming aliases in `sources/aliases`
- adding or changing user-facing shell functions
- creating, removing, or renaming executable scripts in `bin/`
- changing how the startup guide appears in new terminals
- refining the formatting, descriptions, or discoverability of `bin/help`

## Detailed Instructions

1. Inspect `sources/aliases`, `sources/functions.zsh`, `bin/`, and `sources/entrypoint` before editing anything.
2. Treat those files as the source of truth. `bin/help` should discover commands from them instead of maintaining a separate registry.
3. Prefer deriving descriptions from nearby comments in the source files. If the generated descriptions are weak, either improve the source comments or add a narrowly scoped override in `bin/help`.
4. Keep the startup hook local-session only. Do not make remote SSH startup heavier than it already is.
5. Preserve the nested-shell guard in `sources/entrypoint` so the guide prints once per terminal, not every time a subshell starts.
6. When adjusting presentation, keep the default output readable at startup and keep detail lookup available through `help <name>`.
7. After changes, run `bash -n bin/help`, `zsh -n sources/entrypoint`, and preview the output with `bin/help --plain`.

## Example Prompts

```text
Update the terminal help after I add a new alias.
Refine the startup command guide in my dotfiles.
Teach Copilot how to maintain bin/help in this repo.
```
