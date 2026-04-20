#!/usr/bin/env bash
# claude-bookmark setup
# Symlinks the CLI to a bin dir on PATH and installs the right shell completion.
# Usage:
#   bash setup.sh                # detect $SHELL, install completion for it
#   bash setup.sh fish|bash|zsh  # force a specific shell
# Env overrides:
#   CLAUDE_BOOKMARK_BIN_DIR  default: $HOME/.local/bin

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_PATH="$PLUGIN_ROOT/scripts/bookmark.sh"
COMPLETIONS_DIR="$PLUGIN_ROOT/completions"

BIN_DIR="${CLAUDE_BOOKMARK_BIN_DIR:-$HOME/.local/bin}"
BIN_TARGET="$BIN_DIR/claude-bookmark"

R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'

ok()    { printf '%s✓%s %s\n' "$GREEN" "$R" "$1"; }
warn()  { printf '%s⚠%s %s\n' "$YELLOW" "$R" "$1"; }
fail()  { printf '%s✗%s %s\n' "$RED" "$R" "$1" >&2; }
info()  { printf '%sℹ%s %s\n' "$CYAN" "$R" "$1"; }
hdr()   { printf '\n%s%s%s\n' "$B" "$1" "$R"; }

# ─── shell detection ────────────────────────────────────────────────────────

detect_shell() {
  local override="${1:-}"
  if [[ -n "$override" ]]; then
    echo "$override"
    return
  fi
  basename "${SHELL:-bash}"
}

# ─── CLI install ────────────────────────────────────────────────────────────

install_cli() {
  hdr "Installing CLI"

  if [[ ! -x "$SCRIPT_PATH" ]]; then
    chmod +x "$SCRIPT_PATH" 2>/dev/null || true
  fi

  mkdir -p "$BIN_DIR"
  ln -sfn "$SCRIPT_PATH" "$BIN_TARGET"
  ok "Linked $BIN_TARGET → $SCRIPT_PATH"

  case ":$PATH:" in
    *":$BIN_DIR:"*) ok "$BIN_DIR is on \$PATH" ;;
    *) warn "$BIN_DIR is not on \$PATH — add it to your shell rc, e.g. 'export PATH=\"$BIN_DIR:\$PATH\"'" ;;
  esac
}

# ─── completion install ────────────────────────────────────────────────────

install_completion_fish() {
  hdr "Installing fish completion"
  local dest="$HOME/.config/fish/completions"
  mkdir -p "$dest"
  cp "$COMPLETIONS_DIR/claude-bookmark.fish" "$dest/claude-bookmark.fish"
  ok "Installed → $dest/claude-bookmark.fish"
  info "Open a new fish shell (or 'source $dest/claude-bookmark.fish') to activate"
}

install_completion_bash() {
  hdr "Installing bash completion"
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
  mkdir -p "$dest"
  cp "$COMPLETIONS_DIR/claude-bookmark.bash" "$dest/claude-bookmark"
  ok "Installed → $dest/claude-bookmark"
  info "Requires bash-completion v2.x — open a new shell or run 'source $dest/claude-bookmark'"
}

install_completion_zsh() {
  hdr "Installing zsh completion"
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
  mkdir -p "$dest"
  cp "$COMPLETIONS_DIR/_claude-bookmark" "$dest/_claude-bookmark"
  ok "Installed → $dest/_claude-bookmark"

  case ":${FPATH:-}:" in
    *":$dest:"*)
      info "fpath already includes $dest — open a new shell to activate"
      ;;
    *)
      info "Add this to your ~/.zshrc, then open a new shell:"
      printf '%s' "$D"
      cat <<EOF
    fpath=($dest \$fpath)
    autoload -U compinit && compinit
EOF
      printf '%s' "$R"
      ;;
  esac
}

# ─── deps ──────────────────────────────────────────────────────────────────

check_deps() {
  hdr "Checking dependencies"
  local missing_required=() missing_optional=()

  if command -v jq >/dev/null 2>&1; then
    ok "jq"
  else
    missing_required+=("jq")
    fail "jq (REQUIRED)"
  fi

  if command -v fzf >/dev/null 2>&1; then
    ok "fzf"
  else
    missing_optional+=("fzf")
    warn "fzf (optional — needed for the interactive TUI)"
  fi

  if [[ "$(uname -s)" == "Darwin" ]] && ! command -v pbcopy >/dev/null 2>&1; then
    warn "pbcopy not found (optional — uuid clipboard copy on macOS)"
  fi

  if [[ ${#missing_required[@]} -gt 0 || ${#missing_optional[@]} -gt 0 ]]; then
    info "Install missing: brew install ${missing_required[*]} ${missing_optional[*]}"
  fi

  if [[ ${#missing_required[@]} -gt 0 ]]; then
    return 1
  fi
}

# ─── main ──────────────────────────────────────────────────────────────────

main() {
  local shell_override="${1:-}"
  local shell
  shell=$(detect_shell "$shell_override")

  printf '%sclaude-bookmark setup%s\n' "$B" "$R"
  info "Detected shell: $shell"
  info "Plugin root:    $PLUGIN_ROOT"

  install_cli

  case "$shell" in
    fish) install_completion_fish ;;
    bash) install_completion_bash ;;
    zsh)  install_completion_zsh ;;
    *)
      warn "Unknown shell '$shell' — skipping completion install."
      info "Pass shell explicitly: bash $0 <fish|bash|zsh>"
      ;;
  esac

  check_deps || true

  hdr "Done"
  info "Try it: claude-bookmark         (interactive TUI)"
  info "        claude-bookmark --help  (full usage)"
}

main "$@"
