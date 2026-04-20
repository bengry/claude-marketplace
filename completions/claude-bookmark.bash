# Bash completion for claude-bookmark
# Install path (with bash-completion v2.x): ${XDG_DATA_HOME:-~/.local/share}/bash-completion/completions/claude-bookmark

_claude_bookmark() {
    local cur sub
    cur="${COMP_WORDS[COMP_CWORD]}"
    sub="${COMP_WORDS[1]:-}"

    local subcommands="tui list save resume delete rename prune help"

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$subcommands -h --help" -- "$cur") )
        return 0
    fi

    case "$sub" in
        resume|r|delete|rm|rename)
            if [[ $COMP_CWORD -eq 2 ]] && command -v jq >/dev/null 2>&1 && [[ -f "$HOME/.claude/bookmarks.json" ]]; then
                local names
                # mapfile preserves names containing spaces.
                mapfile -t names < <(jq -r '.[].name' "$HOME/.claude/bookmarks.json" 2>/dev/null)
                local IFS=$'\n'
                COMPREPLY=( $(compgen -W "${names[*]}" -- "$cur") )
                return 0
            fi
            ;;
    esac

    if [[ "$sub" == "rename" && $COMP_CWORD -ge 3 ]]; then
        COMPREPLY=( $(compgen -W "--force" -- "$cur") )
        return 0
    fi

    return 0
}

complete -F _claude_bookmark claude-bookmark
