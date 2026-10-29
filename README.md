# .envs

Personal dotfiles.

| Path | What |
|------|------|
| `.tmux.conf` | tmux config (vi copy mode, `C-h/j/k/l` pane navigation) |
| `claude/` | Claude Code config (`~/.claude`), auto-synced on startup — see [claude/README.md](claude/README.md) |

## Setup

```sh
git clone git@github.com:TheSpaceT/.envs.git ~/.envs

# tmux
ln -s ~/.envs/.tmux.conf ~/.tmux.conf

# Claude Code
~/.envs/claude/sync.sh --install   # also hooks claude wrapper into ~/.zshrc
rtk init -g
```

New files must be whitelisted in `.gitignore` (everything is ignored by default).
