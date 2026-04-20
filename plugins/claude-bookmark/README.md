# claude-bookmark

Bookmark Claude Code sessions for later resume, with an `fzf`-powered TUI picker.

Save the current session in one keystroke. Browse, preview, and resume past sessions from any terminal — fuzzy search by name or path, see the last user message in a preview pane, hit `enter` to drop back into that conversation.

## Install

Inside Claude Code:

```
/plugin marketplace add bengry/claude-marketplace
/plugin install claude-bookmark@bengry-marketplace
/bookmark-setup
```

`/bookmark-setup` symlinks the `claude-bookmark` CLI into `~/.local/bin` and installs shell completion for your detected shell (`fish`, `bash`, or `zsh`). Override with `/bookmark-setup zsh` if needed.

### Dependencies

- `jq` (required)
- `fzf` (required for the interactive TUI)
- `pbcopy` (macOS, optional — for `ctrl-y` clipboard copy)

```sh
brew install jq fzf
```

## Slash commands

| Command | What it does |
|---|---|
| `/bookmark [name]` | Bookmark the current session. If no name is given, Claude generates a one-sentence summary. |
| `/bookmarks` | Print all bookmarks (plain list — slash command output is captured, not interactive). |
| `/bookmark-setup [shell]` | (Re)install CLI symlink + shell completion. |

## Terminal CLI

Run `claude-bookmark` (no args) to open the interactive TUI:

```
bookmark> █                        ┌── name:    Fixing the /bookmark slash command…
▸ Fixing the /bookmark slash …   │  cwd:     /Users/bengr/projects-personal
  Designing /bookmark             │  created: 2026-04-20T22:36:39Z
  Investigating ingest backlog    │  session: f9541ddc-b258-499d-899f-2628f4c660f3
                                  │  resume:  claude --resume f9541ddc-…
                                  │
                                  │  ── last user message ─────────────────
                                  │  can we change the `claude-bookmark` …
```

### TUI keys

| Key | Action |
|---|---|
| `enter` | Resume the selected session (`claude --resume <uuid>`) |
| `ctrl-d` | Delete the bookmark, then reopen the picker |
| `ctrl-y` | Copy the session UUID to clipboard (macOS) |
| `esc` | Cancel |

### Subcommands

```sh
claude-bookmark                       # interactive TUI (or plain list if not on a tty)
claude-bookmark tui                   # force interactive picker
claude-bookmark list                  # plain list (always)
claude-bookmark resume <name|uuid>    # print 'claude --resume <uuid>' + clipboard
claude-bookmark delete <name|uuid>    # remove a bookmark
claude-bookmark rename <old> <new>    # rename (use --force to overwrite)
claude-bookmark prune                 # drop entries whose transcripts are gone
claude-bookmark --help                # full usage
```

Tab completion (in `fish`, `bash`, or `zsh`) suggests subcommands and completes bookmark names from `~/.claude/bookmarks.json`.

## Storage

Bookmarks are stored as a single JSON array at `~/.claude/bookmarks.json`. Each entry tracks `name`, `session_id`, `cwd`, `created_at`, and `transcript_path`.

## License

MIT
