#!/usr/bin/env bash
# Sync ~/.claude config with the ~/.envs git repo.
#
#   sync.sh            detach and sync in background (used by SessionStart hook)
#   sync.sh --fg       sync in foreground
#   sync.sh --pull     quick foreground pull before claude starts (see claude.zsh)
#   sync.sh --install  link repo files into ~/.claude, repo wins (backs up local to *.bak.<timestamp>),
#                      and source claude.zsh from ~/.zshrc

#
# Managed files live in $REPO/claude and are symlinked into ~/.claude.
# If Claude Code replaces a symlink with a regular file (atomic write),
# the local version wins and is moved back into the repo.
set -uo pipefail

REPO="${ENVS_REPO:-$HOME/.envs}"
SRC="$REPO/claude"
DST="$HOME/.claude"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/claude-envs-sync.log"
MANAGED=(CLAUDE.md RTK.md settings.json skills/grilling)

export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"
export GIT_TERMINAL_PROMPT=0

log() { echo "[$(date '+%F %T')] $*"; }

# with_timeout SECONDS CMD...: GNU timeout, coreutils gtimeout on macOS, or none.
with_timeout() {
  local t=$1; shift
  if command -v timeout >/dev/null; then timeout "$t" "$@"
  elif command -v gtimeout >/dev/null; then gtimeout "$t" "$@"
  else "$@"; fi
}

lock() {
  # mkdir-based lock (flock is not available on macOS); stale after 10 min.
  LOCK="$REPO/.git/claude-sync.lock.d"
  find "$LOCK" -maxdepth 0 -mmin +10 -exec rm -rf {} + 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || return 1
  trap 'rm -rf "$LOCK"' EXIT
}

pull() {
  if ! with_timeout "$1" git pull -q --rebase --autostash; then
    git rebase --abort 2>/dev/null
    return 1
  fi
}

# link REL MODE: MODE=local (local file wins) or repo (repo file wins)
link() {
  local rel=$1 mode=$2 src="$SRC/$1" dst="$DST/$1"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    return
  fi
  mkdir -p "$(dirname "$dst")" "$(dirname "$src")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    if [[ "$mode" == local || ! -e "$src" ]]; then
      log "absorb local $rel into repo"
      rm -rf "$src"
      mv "$dst" "$src"
    else
      local bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
      log "backup local $rel to $bak"
      mv "$dst" "$bak"
    fi
  elif [[ -L "$dst" ]]; then
    rm "$dst"
  fi
  [[ -e "$src" ]] && ln -s "$src" "$dst"
}

link_all() {
  local rel
  for rel in "${MANAGED[@]}"; do link "$rel" "$1"; done
}

case "${1:-}" in
  --install)
    link_all repo
    line='[ -f "$HOME/.envs/claude/claude.zsh" ] && source "$HOME/.envs/claude/claude.zsh"'
    grep -qF "$line" "$HOME/.zshrc" 2>/dev/null || echo "$line" >>"$HOME/.zshrc"
    exit 0
    ;;
  --pull)
    # Runs before claude starts, so pulled config applies to this session.
    cd "$REPO" && lock || exit 0
    export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=3"
    pull 5 2>/dev/null && link_all local >>"$LOG"
    exit 0
    ;;
  --fg) ;;
  *)
    mkdir -p "$(dirname "$LOG")"
    if command -v setsid >/dev/null; then
      setsid nohup "$0" --fg >>"$LOG" 2>&1 </dev/null &
    else
      nohup "$0" --fg >>"$LOG" 2>&1 </dev/null &
    fi
    exit 0
    ;;
esac

cd "$REPO" || exit 1
lock || exit 0

link_all local

git add -A -- claude
if ! git diff --cached --quiet; then
  git commit -q -m "chore(claude): sync from $(hostname)" && log "committed local changes"
fi

before=$(git rev-parse HEAD)
if ! pull 60; then
  log "pull failed, resolve manually in $REPO"
  exit 1
fi

# Repo may have brought new or changed files.
link_all local

if [[ -n "$(git log --oneline '@{u}..' 2>/dev/null)" ]]; then
  with_timeout 60 git push -q && log "pushed" || log "push failed"
fi

# Local commits are already in $before, so this diff is upstream changes only.
git diff --quiet "$before" HEAD -- claude || log "pulled new config, restart claude to apply"
