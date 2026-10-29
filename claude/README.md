# Claude Code config

Files here are symlinked into `~/.claude` and kept in sync with this repo:

- `claude.zsh` — wraps `claude` to `git pull` (5s timeout) before start, so new config applies right away.
- `sync.sh` — SessionStart hook, runs in background: commit local changes -> `pull --rebase` -> push.
  If Claude Code replaces a symlink with a regular file, the local file is moved back into the repo.
- `statusline.sh` — status line: context window usage and remaining rate limits.

```
ctx 8% 76k/1M · 5h 87% ↻15:10 · 7d 76% ↻Wed 11:00
```

`ctx` — context used; `5h`/`7d` — limit left, `↻` — reset time.
Green / yellow / red by usage: < 50% / < 80% / more.

Setup on a new machine:

```sh
git clone git@github.com:TheSpaceT/.envs.git ~/.envs
~/.envs/claude/sync.sh --install   # link files (repo wins, local saved as *.bak.<ts>), source claude.zsh in ~/.zshrc
rtk init -g                        # PreToolUse hook (rtk-rewrite.sh) is managed by rtk
```

Managed files: see `MANAGED` in `sync.sh`. Do not put secrets here — repo is public.
Log: `~/.cache/claude-envs-sync.log`. Works on Linux and macOS (bash 3.2, no GNU tools needed).
