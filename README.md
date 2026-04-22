# These are my dotfiles

Getting started:

```bash
sudo softwareupdate -i -a
bash -c "`curl -fsSL https://raw.githubusercontent.com/jonmagic/dotfiles/main/remote-install.sh`"
```

## Terminal help

Opening a new local interactive terminal prints a generated command guide sourced from:

- `sources/aliases`
- `sources/functions.zsh`
- executable scripts in `bin/`

Run `help` at any time to show the guide again, `help scripts` to focus on scripts, or `help <name>` for one command.
