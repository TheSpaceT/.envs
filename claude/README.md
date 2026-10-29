# Claude Code config

Files here are symlinked into `~/.claude` and kept in sync with this repo:

- `claude.zsh` — wraps `claude` to `git pull` (5s timeout) before start, so new config applies right away.
- `sync.sh` — SessionStart hook, runs in background: commit local changes -> `pull --rebase` -> push.
  If Claude Code replaces a symlink with a regular file, the local file is moved back into the repo.
- `statusline.sh` — status line: `model · dir · branch* · envs state · caveman badge`.

Envs state in the status line:

| | |
|-|-|
| `✓ envs` | in sync |
| `⟳ envs` | syncing |
| `↓ envs: restart` | new config pulled mid-session, restart claude to apply |
| `✗ envs pull/push` | sync failed, see log |

Setup on a new machine:

```sh
git clone git@github.com:TheSpaceT/.envs.git ~/.envs
~/.envs/claude/sync.sh --install   # link files (repo wins, local saved as *.bak.<ts>), source claude.zsh in ~/.zshrc
rtk init -g                        # PreToolUse hook (rtk-rewrite.sh) is managed by rtk
```

Managed files: see `MANAGED` in `sync.sh`. Do not put secrets here — repo is public.
Log: `~/.cache/claude-envs-sync.log`. Works on Linux and macOS (bash 3.2, no GNU tools needed).
