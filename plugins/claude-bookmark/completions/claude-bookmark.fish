# Completions for claude-bookmark (see scripts/bookmark.sh)

set -l subs tui pick select list ls save save-here resume r delete rm rename prune help

complete -c claude-bookmark -f

complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -a tui    -d "Interactive picker (fzf TUI)"
complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -a list   -d "Plain list of bookmarks"
complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -a save   -d "Save a session bookmark"
complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -a resume -d "Print resume command (+ clipboard)"
complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -a delete -d "Delete a bookmark"
complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -a rename -d "Rename a bookmark"
complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -a prune  -d "Remove bookmarks whose transcripts are gone"
complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -a help   -d "Show help"

complete -c claude-bookmark -n "not __fish_seen_subcommand_from $subs" -s h -l help -d "Show help"

function __claude_bookmark_names
    if test -f ~/.claude/bookmarks.json
        jq -r '.[].name' ~/.claude/bookmarks.json 2>/dev/null
    end
end

complete -c claude-bookmark -n "__fish_seen_subcommand_from resume r delete rm rename" -a "(__claude_bookmark_names)"
complete -c claude-bookmark -n "__fish_seen_subcommand_from rename" -l force -d "Overwrite existing bookmark with new name"
