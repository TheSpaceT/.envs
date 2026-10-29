#!/usr/bin/env bash
# Claude Code status line: context window usage and remaining rate limits.
#   ctx 7% 73k/1M · 5h 88% ↻15:30 · 7d 76% ↻Mon 12:00
# Reads session JSON from stdin.
input=$(cat)

# ctx used %, ctx tokens, ctx size, 5h used %, 5h reset, 7d used %, 7d reset
if command -v jq >/dev/null; then
  row=$(jq -r '[.context_window.used_percentage, .context_window.total_input_tokens,
    .context_window.context_window_size,
    .rate_limits.five_hour.used_percentage, .rate_limits.five_hour.resets_at,
    .rate_limits.seven_day.used_percentage, .rate_limits.seven_day.resets_at]
    | map(. // "" | tostring) | join("\t")' <<<"$input" 2>/dev/null)
else
  row=$(python3 -c '
import json, sys
d = json.load(sys.stdin)
def g(path):
    v = d
    for k in path.split("."):
        v = (v or {}).get(k)
    return "" if v is None else str(v)
print("\t".join(g(p) for p in [
    "context_window.used_percentage", "context_window.total_input_tokens",
    "context_window.context_window_size",
    "rate_limits.five_hour.used_percentage", "rate_limits.five_hour.resets_at",
    "rate_limits.seven_day.used_percentage", "rate_limits.seven_day.resets_at"]))
' <<<"$input" 2>/dev/null)
fi
IFS=$'\t' read -r ctx_pct ctx_tok ctx_size h5_pct h5_reset d7_pct d7_reset <<<"$row"

c() { printf '\033[%sm%s\033[0m' "$1" "$2"; }

# Color by how much is used: green < 50, yellow < 80, red otherwise.
level() {
  local p=${1%.*}
  if (( p < 50 )); then echo 32; elif (( p < 80 )); then echo 33; else echo 31; fi
}

human() {
  local n=${1%.*}
  if (( n >= 1000000 )); then echo "$((n / 1000000))M"
  elif (( n >= 1000 )); then echo "$((n / 1000))k"
  else echo "$n"; fi
}

# Unix time -> local time, GNU date or BSD date (macOS).
at() { date -d "@$1" +"$2" 2>/dev/null || date -r "$1" +"$2" 2>/dev/null; }

parts=()
if [[ -n "$ctx_pct" ]]; then
  ctx="ctx ${ctx_pct%.*}%"
  [[ -n "$ctx_tok" && -n "$ctx_size" ]] && ctx+=" $(human "$ctx_tok")/$(human "$ctx_size")"
  parts+=("$(c "$(level "$ctx_pct")" "$ctx")")
fi
if [[ -n "$h5_pct" ]]; then
  parts+=("$(c "$(level "$h5_pct")" "5h $((100 - ${h5_pct%.*}))%")$(c 90 " ↻$(at "$h5_reset" %H:%M)")")
fi
if [[ -n "$d7_pct" ]]; then
  parts+=("$(c "$(level "$d7_pct")" "7d $((100 - ${d7_pct%.*}))%")$(c 90 " ↻$(at "$d7_reset" '%a %H:%M')")")
fi

sep=$(c 90 ' · ')
out=""
for p in ${parts[@]+"${parts[@]}"}; do out+="${out:+$sep}$p"; done
printf '%s' "$out"
