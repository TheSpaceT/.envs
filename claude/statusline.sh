#!/usr/bin/env bash
# Claude Code status line: model · dir · git branch · .envs sync state · caveman badge.
# Reads session JSON from stdin.
input=$(cat)

field() {
  if command -v jq >/dev/null; then
    jq -r "$1 // empty" <<<"$input" 2>/dev/null
  else
    python3 -c 'import json,sys; d=json.load(sys.stdin)
for k in sys.argv[1].lstrip(".").split("."): d=(d or {}).get(k)
print(d or "")' "$1" <<<"$input" 2>/dev/null
  fi
}

c() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
SEP=$(c 90 ' · ')

model=$(field .model.display_name)
dir=$(field .workspace.current_dir)
[[ -z "$dir" ]] && dir=$PWD

out=$(c 1 "${model:-claude}")
out+="$SEP$(c 34 "${dir##*/}")"

if branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null) && [[ -n "$branch" ]]; then
  dirty=$(git -C "$dir" --no-optional-locks status --porcelain -uno 2>/dev/null | head -1)
  out+="$SEP$(c 35 "$branch${dirty:+*}")"
fi

state=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/claude-envs-sync.state" 2>/dev/null)
case "$state" in
  ok)       out+="$SEP$(c 32 '✓ envs')" ;;
  syncing)  out+="$SEP$(c 33 '⟳ envs')" ;;
  pulled)   out+="$SEP$(c 36 '↓ envs: restart')" ;;
  error*)   out+="$SEP$(c 31 "✗ envs ${state#error: }")" ;;
esac

badge=$(ls "$HOME"/.claude/plugins/cache/caveman/caveman/*/hooks/caveman-statusline.sh 2>/dev/null | tail -1)
[[ -n "$badge" ]] && out+=" $(bash "$badge")"

printf '%s' "$out"
