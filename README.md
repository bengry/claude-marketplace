# bengry's Claude Code marketplace

A small marketplace of [Claude Code](https://docs.claude.com/en/docs/claude-code) plugins by [@bengry](https://github.com/bengry).

## Add the marketplace

Inside Claude Code:

```
/plugin marketplace add bengry/claude-marketplace
```

Then install any plugin from the list below with:

```
/plugin install <plugin-name>@bengry-marketplace
```

## Plugins

| Plugin | Description |
|---|---|
| [`claude-bookmark`](plugins/claude-bookmark/) | Bookmark Claude Code sessions for later resume, with an `fzf`-powered TUI picker. |

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest (this repo)
plugins/
└── claude-bookmark/              # one directory per plugin
    ├── .claude-plugin/plugin.json
    ├── commands/
    ├── scripts/
    ├── completions/
    └── README.md
```

Each plugin has its own README with full install + usage details.

## License

MIT
