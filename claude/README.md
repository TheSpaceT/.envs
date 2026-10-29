# Claude Code config

Files here are symlinked into `~/.claude` and synced by `sync.sh`
(SessionStart hook, runs in background on every `claude` startup):
commit local changes -> `pull --rebase` -> push.

Setup on a new machine:

```sh
git clone git@github.com:TheSpaceT/.envs.git ~/.envs
~/.envs/claude/sync.sh --install   # repo wins, local files saved as *.bak.<ts>
rtk init -g                        # PreToolUse hook (rtk-rewrite.sh) is managed by rtk
```

Managed files: see `MANAGED` in `sync.sh`. Do not put secrets here — repo is public.
Log: `~/.cache/claude-envs-sync.log`.
