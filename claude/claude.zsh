# Pull ~/.envs before Claude Code starts so new config applies to this session.
# Sourced from ~/.zshrc (added by `sync.sh --install`).
claude() {
  "$HOME/.envs/claude/sync.sh" --pull
  command claude "$@"
}
