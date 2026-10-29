#!/usr/bin/env bash
# Sync ~/.claude config with the ~/.envs git repo.
#
#   sync.sh            detach and sync in background (used by SessionStart hook)
#   sync.sh --fg       sync in foreground
#   sync.sh --install  link repo files into ~/.claude, repo wins (backs up local to *.bak.<timestamp>)
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

# Portable timeout: GNU timeout, coreutils gtimeout on macOS, or none.
with_timeout() {
  if command -v timeout >/dev/null; then timeout 60 "$@"
  elif command -v gtimeout >/dev/null; then gtimeout 60 "$@"
  else "$@"; fi
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
# mkdir-based lock (flock is not available on macOS); stale after 10 min.
LOCK="$REPO/.git/claude-sync.lock.d"
find "$LOCK" -maxdepth 0 -mmin +10 -exec rm -rf {} + 2>/dev/null
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rm -rf "$LOCK"' EXIT

link_all local

git add -A -- claude
if ! git diff --cached --quiet; then
  git commit -q -m "chore(claude): sync from $(hostname)" && log "committed local changes"
fi

if ! with_timeout git pull -q --rebase --autostash; then
  git rebase --abort 2>/dev/null
  log "pull failed, resolve manually in $REPO"
  exit 1
fi

# Repo may have brought new or changed files.
link_all local

if [[ -n "$(git log --oneline '@{u}..' 2>/dev/null)" ]]; then
  with_timeout git push -q && log "pushed" || log "push failed"
fi
