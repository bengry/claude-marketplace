#!/bin/bash
# claude-bookmark — bookmark Claude Code sessions for later resume
# Storage: ~/.claude/bookmarks.json (single JSON array)

set -euo pipefail

BOOKMARKS_FILE="${BOOKMARKS_FILE:-$HOME/.claude/bookmarks.json}"
PROJECTS_ROOT="$HOME/.claude/projects"

# ─── helpers ────────────────────────────────────────────────────────────────

ensure_bookmarks_file() {
  if [[ ! -f "$BOOKMARKS_FILE" ]]; then
    mkdir -p "$(dirname "$BOOKMARKS_FILE")"
    echo "[]" > "$BOOKMARKS_FILE"
  fi
}

encode_cwd() {
  # /Users/bengr/x → -Users-bengr-x
  printf '%s' "$1" | sed 's|/|-|g'
}

resolve_session_id() {
  # Args: provided_session_id, cwd
  # Echo resolved session_id to stdout; warn to stderr on fallback.
  local provided="$1"
  local cwd="$2"
  local encoded proj_dir
  encoded=$(encode_cwd "$cwd")
  proj_dir="$PROJECTS_ROOT/$encoded"

  # If caller didn't pass a session id, try the env vars Claude Code/companions set.
  if [[ -z "$provided" ]]; then
    provided="${CLAUDE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-${CLAUDECODE_SESSION_ID:-${CODEX_COMPANION_SESSION_ID:-}}}}"
  fi

  if [[ -n "$provided" && -f "$proj_dir/$provided.jsonl" ]]; then
    printf '%s' "$provided"
    return 0
  fi

  if [[ ! -d "$proj_dir" ]]; then
    echo "Error: no project directory for cwd: $cwd" >&2
    echo "       (expected $proj_dir)" >&2
    return 1
  fi

  local most_recent=""
  most_recent=$(ls -t "$proj_dir"/*.jsonl 2>/dev/null | head -n1 || true)
  if [[ -z "$most_recent" ]]; then
    echo "Error: no .jsonl session files in $proj_dir" >&2
    return 1
  fi

  local fallback_id
  fallback_id=$(basename "$most_recent" .jsonl)
  if [[ -z "$provided" ]]; then
    echo "ℹ Using most recent session in this cwd: $fallback_id" >&2
  else
    echo "⚠ Provided session_id ($provided) not found; falling back to most recent: $fallback_id" >&2
  fi
  printf '%s' "$fallback_id"
}

write_atomic() {
  # Args: target_file, source_temp_file
  mv "$2" "$1"
}

# ─── subcommands ────────────────────────────────────────────────────────────

cmd_save() {
  local session_id="${1:-}"
  local cwd="${2:-$PWD}"
  local name="${3:-}"

  ensure_bookmarks_file

  local resolved
  if ! resolved=$(resolve_session_id "$session_id" "$cwd"); then
    return 1
  fi

  local encoded transcript_path
  encoded=$(encode_cwd "$cwd")
  transcript_path="$PROJECTS_ROOT/$encoded/$resolved.jsonl"

  local placeholder_used="no"
  if [[ -z "$name" ]]; then
    name="pending-${resolved:0:8}"
    placeholder_used="yes"
  fi

  local existing
  existing=$(jq --arg n "$name" '[.[] | select(.name == $n)] | length' "$BOOKMARKS_FILE")
  if [[ "$existing" -gt 0 ]]; then
    echo "⚠ Overwriting existing bookmark with same name" >&2
  fi

  local created_at
  created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local tmp
  tmp=$(mktemp)
  jq --arg n "$name" \
     --arg sid "$resolved" \
     --arg c "$cwd" \
     --arg ca "$created_at" \
     --arg tp "$transcript_path" \
     '[.[] | select(.name != $n)] + [{name: $n, session_id: $sid, cwd: $c, created_at: $ca, transcript_path: $tp}]' \
     "$BOOKMARKS_FILE" > "$tmp"
  write_atomic "$BOOKMARKS_FILE" "$tmp"

  if [[ "$placeholder_used" == "yes" ]]; then
    echo "✓ Saved bookmark with placeholder name <pending:$name>"
    echo "  cwd:    $cwd"
    echo "  resume: claude --resume $resolved"
    echo "  (no name was provided — Claude should rename this to a 1-sentence summary)"
  else
    echo "✓ Saved bookmark: $name"
    echo "  cwd:    $cwd"
    echo "  resume: claude --resume $resolved"
  fi
}

cmd_rename() {
  local old="${1:-}"
  local new="${2:-}"
  local force="no"
  if [[ "${3:-}" == "--force" ]]; then
    force="yes"
  fi

  if [[ -z "$old" || -z "$new" ]]; then
    echo "Usage: claude-bookmark rename <old_name> <new_name> [--force]" >&2
    return 1
  fi

  ensure_bookmarks_file

  local exists
  exists=$(jq --arg n "$old" '[.[] | select(.name == $n)] | length' "$BOOKMARKS_FILE")
  if [[ "$exists" -eq 0 ]]; then
    echo "Error: bookmark not found: $old" >&2
    return 1
  fi

  local conflict
  conflict=$(jq --arg n "$new" '[.[] | select(.name == $n)] | length' "$BOOKMARKS_FILE")
  if [[ "$conflict" -gt 0 && "$force" != "yes" ]]; then
    echo "Error: a bookmark named '$new' already exists (pass --force to overwrite)" >&2
    return 1
  fi

  local tmp
  tmp=$(mktemp)
  if [[ "$force" == "yes" && "$conflict" -gt 0 ]]; then
    jq --arg o "$old" --arg n "$new" \
       '[.[] | select(.name != $n)] | map(if .name == $o then .name = $n else . end)' \
       "$BOOKMARKS_FILE" > "$tmp"
  else
    jq --arg o "$old" --arg n "$new" \
       'map(if .name == $o then .name = $n else . end)' \
       "$BOOKMARKS_FILE" > "$tmp"
  fi
  write_atomic "$BOOKMARKS_FILE" "$tmp"

  echo "✓ Renamed: $old → $new"
}

cmd_list() {
  ensure_bookmarks_file

  local count
  count=$(jq 'length' "$BOOKMARKS_FILE")
  if [[ "$count" -eq 0 ]]; then
    echo "No bookmarks yet. Inside Claude Code: /bookmark <name?>"
    echo "From terminal:                       claude-bookmark save \"\" \"\$PWD\" <name>"
    return 0
  fi

  local now
  now=$(date -u +%s)

  jq -r --argjson now "$now" '
    .[] |
    (.created_at | fromdateiso8601) as $ts |
    ($now - $ts) as $age |
    (
      if   $age < 60     then "\($age | floor)s ago"
      elif $age < 3600   then "\($age / 60 | floor)m ago"
      elif $age < 86400  then "\($age / 3600 | floor)h ago"
      else                    "\($age / 86400 | floor)d ago"
      end
    ) as $age_str |
    "▸ \(.name)\n  cwd:    \(.cwd) · \($age_str) · \(.session_id[0:8])…\n  resume: claude --resume \(.session_id)\n"
  ' "$BOOKMARKS_FILE"
}

cmd_default() {
  # Interactive TUI when possible, otherwise plain list (e.g. slash command).
  ensure_bookmarks_file
  local count
  count=$(jq 'length' "$BOOKMARKS_FILE")
  if [[ "$count" -eq 0 ]]; then
    cmd_list
    return 0
  fi
  if [[ -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    cmd_tui
  else
    cmd_list
  fi
}

cmd_tui() {
  ensure_bookmarks_file
  if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf is not installed (brew install fzf)" >&2
    return 1
  fi

  local count
  count=$(jq 'length' "$BOOKMARKS_FILE")
  if [[ "$count" -eq 0 ]]; then
    cmd_list
    return 0
  fi

  local script_path="$0"
  local now
  now=$(date -u +%s)

  # Build TAB-delimited rows: session_id \t name \t age \t cwd
  local rows
  rows=$(jq -r --argjson now "$now" '
    .[] |
    (.created_at | fromdateiso8601) as $ts |
    ($now - $ts) as $age |
    (
      if   $age < 60     then "\($age | floor)s"
      elif $age < 3600   then "\($age / 60 | floor)m"
      elif $age < 86400  then "\($age / 3600 | floor)h"
      else                    "\($age / 86400 | floor)d"
      end
    ) as $age_str |
    [.session_id, .name, $age_str, .cwd] | @tsv
  ' "$BOOKMARKS_FILE")

  local result
  set +e
  result=$(printf '%s\n' "$rows" | fzf \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=2,3,4 \
    --nth=1,2 \
    --preview="bash '$script_path' _preview {1}" \
    --preview-window=right:55%:wrap \
    --header='enter: resume · ctrl-d: delete · ctrl-y: copy uuid · esc: cancel' \
    --expect=ctrl-d,ctrl-y \
    --prompt='bookmark> ')
  local fzf_status=$?
  set -e

  if [[ $fzf_status -ne 0 || -z "$result" ]]; then
    return 0
  fi

  local key line uuid name
  key=$(printf '%s\n' "$result" | sed -n '1p')
  line=$(printf '%s\n' "$result" | sed -n '2p')
  uuid=$(printf '%s' "$line" | awk -F'\t' '{print $1}')
  name=$(printf '%s' "$line" | awk -F'\t' '{print $2}')

  case "$key" in
    ctrl-d)
      cmd_delete "$name" || true
      cmd_tui
      ;;
    ctrl-y)
      if command -v pbcopy >/dev/null 2>&1; then
        printf '%s' "$uuid" | pbcopy
        echo "✓ Copied uuid to clipboard: $uuid"
      else
        echo "$uuid"
      fi
      ;;
    *)
      echo "▶ Resuming: $name"
      exec claude --resume "$uuid"
      ;;
  esac
}

cmd_preview() {
  # Render preview pane for a single bookmark (called by fzf with --ansi).
  local uuid="${1:-}"
  [[ -z "$uuid" ]] && return 0
  ensure_bookmarks_file

  local data
  data=$(jq -r --arg sid "$uuid" '
    .[] | select(.session_id == $sid) |
    [.name, .cwd, .created_at, .session_id, .transcript_path] | @tsv
  ' "$BOOKMARKS_FILE")

  if [[ -z "$data" ]]; then
    echo "(no bookmark for $uuid)"
    return 0
  fi

  local name cwd created sid tp
  IFS=$'\t' read -r name cwd created sid tp <<<"$data"

  # ANSI styles
  local R=$'\033[0m'           # reset
  local B=$'\033[1m'           # bold
  local D=$'\033[2m'           # dim
  local LBL=$'\033[1;36m'      # bold cyan — labels
  local V_NAME=$'\033[1;33m'   # bold yellow — name
  local V_PATH=$'\033[34m'     # blue — path
  local V_TIME=$'\033[2;37m'   # dim white — timestamp
  local V_ID=$'\033[35m'       # magenta — uuid
  local V_CMD=$'\033[32m'      # green — runnable command
  local DIV=$'\033[2;90m'      # dim grey — dividers
  local HDR=$'\033[1;35m'      # bold magenta — section headers

  fmt_field() {
    # fmt_field <label> <value_style> <value>
    printf '%s%-9s%s %s%s%s\n' "$LBL" "$1:" "$R" "$2" "$3" "$R"
  }

  fmt_field "name"    "$V_NAME" "$name"
  fmt_field "cwd"     "$V_PATH" "$cwd"
  fmt_field "created" "$V_TIME" "$created"
  fmt_field "session" "$V_ID"   "$sid"
  fmt_field "resume"  "$V_CMD"  "claude --resume $sid"
  echo

  if [[ -f "$tp" ]]; then
    printf '%s── last user message %s%s\n' "$HDR" "──────────────────────────" "$R"
    # Pull recent user message text from the JSONL transcript.
    tail -n 200 "$tp" 2>/dev/null \
      | jq -r 'select(.type == "user") | (.message.content // "") | if type == "string" then . else (map(select(.type == "text") | .text) | join("\n")) end' 2>/dev/null \
      | tail -n 30 \
      | head -c 2000
  else
    printf '%s(transcript file missing: %s)%s\n' "$D" "$tp" "$R"
  fi
}

find_uuid_for_query() {
  # Echo the matching session_id, or empty if not found.
  # Match priority: exact name, then session_id prefix.
  local query="$1"
  jq -r --arg q "$query" '
    [
      (.[] | select(.name == $q) | .session_id),
      (.[] | select(.session_id | startswith($q)) | .session_id)
    ] | first // empty
  ' "$BOOKMARKS_FILE"
}

cmd_resume() {
  local query="${1:-}"
  if [[ -z "$query" ]]; then
    echo "Usage: claude-bookmark resume <name-or-id>" >&2
    return 1
  fi

  ensure_bookmarks_file

  local uuid
  uuid=$(find_uuid_for_query "$query")
  if [[ -z "$uuid" ]]; then
    echo "Error: no bookmark matches: $query" >&2
    return 1
  fi

  echo "claude --resume $uuid"

  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$uuid" | pbcopy
    echo "(uuid copied to clipboard)" >&2
  fi
}

cmd_delete() {
  local query="${1:-}"
  if [[ -z "$query" ]]; then
    echo "Usage: claude-bookmark delete <name-or-id>" >&2
    return 1
  fi

  ensure_bookmarks_file

  local before after
  before=$(jq 'length' "$BOOKMARKS_FILE")

  local tmp
  tmp=$(mktemp)
  jq --arg q "$query" \
     '[.[] | select(.name != $q and ((.session_id | startswith($q)) | not))]' \
     "$BOOKMARKS_FILE" > "$tmp"
  write_atomic "$BOOKMARKS_FILE" "$tmp"

  after=$(jq 'length' "$BOOKMARKS_FILE")
  local removed=$((before - after))
  if [[ "$removed" -eq 0 ]]; then
    echo "Error: no bookmark found matching: $query" >&2
    return 1
  fi
  echo "✓ Deleted $removed bookmark(s) matching: $query"
}

cmd_prune() {
  ensure_bookmarks_file

  local before
  before=$(jq 'length' "$BOOKMARKS_FILE")

  local tmp
  tmp=$(mktemp)

  # Walk entries, keep only those whose transcript_path still exists.
  jq -c '.[]' "$BOOKMARKS_FILE" | {
    first="yes"
    printf '['
    while IFS= read -r entry; do
      tp=$(printf '%s' "$entry" | jq -r '.transcript_path')
      if [[ -f "$tp" ]]; then
        if [[ "$first" == "yes" ]]; then
          first="no"
        else
          printf ','
        fi
        printf '%s' "$entry"
      fi
    done
    printf ']'
  } > "$tmp"
  # Re-format with jq (also validates JSON)
  local tmp2
  tmp2=$(mktemp)
  jq '.' "$tmp" > "$tmp2"
  rm -f "$tmp"
  write_atomic "$BOOKMARKS_FILE" "$tmp2"

  local after
  after=$(jq 'length' "$BOOKMARKS_FILE")
  echo "✓ Pruned $((before - after)) bookmark(s); $after remaining"
}

cmd_help() {
  cat <<'EOF'
claude-bookmark — bookmark Claude Code sessions for later resume

Usage:
  claude-bookmark                            # interactive TUI (fzf) when on a tty,
                                             #   else falls back to plain list
  claude-bookmark tui                        # force interactive picker (requires fzf)
  claude-bookmark list                       # plain list (always)
  claude-bookmark save <session_id> <cwd> [name]
                                             # save bookmark (name optional)
  claude-bookmark rename <old> <new> [--force]
                                             # rename a bookmark
  claude-bookmark resume <name-or-id>        # print 'claude --resume <uuid>'
                                             #   and copy uuid to clipboard (macOS)
  claude-bookmark delete <name-or-id>        # remove a bookmark
  claude-bookmark prune                      # drop entries whose .jsonl is gone

TUI keys: enter = resume · ctrl-d = delete · ctrl-y = copy uuid · esc = cancel

Storage: ~/.claude/bookmarks.json
Inside Claude Code, use the slash commands /bookmark and /bookmarks instead.
EOF
}

# ─── dispatch ───────────────────────────────────────────────────────────────

cmd="${1:-__default__}"
if [[ $# -gt 0 ]]; then shift; fi

case "$cmd" in
  __default__) cmd_default ;;
  tui|pick|select) cmd_tui ;;
  save)        cmd_save "$@" ;;
  save-here)   cmd_save "" "$@" ;;
  rename)      cmd_rename "$@" ;;
  list|ls)     cmd_list "$@" ;;
  resume|r)    cmd_resume "$@" ;;
  delete|rm)   cmd_delete "$@" ;;
  prune)       cmd_prune "$@" ;;
  _preview)    cmd_preview "$@" ;;
  -h|--help|help) cmd_help ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Try: claude-bookmark --help" >&2
    exit 1
    ;;
esac
