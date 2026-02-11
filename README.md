# cass-cm-mcp

A stdio [MCP](https://modelcontextprotocol.io/) server that bridges **cass** (coding agent session search) and **cm** (cass memory system) into a single tool server for Claude Code, Codex CLI, Gemini CLI, and other MCP-compatible AI coding agents.

Neither cass nor cm ships a working stdio MCP server today. This bridge fills that gap with 10 tools, optimized search output, and zero external Python dependencies.

## Prerequisites

| Dependency | Version | Install |
|------------|---------|---------|
| Python | 3.7+ | Usually pre-installed |
| [cass](https://github.com/Dicklesworthstone/coding_agent_session_search) | 0.1.x | See cass repo |
| [cm](https://github.com/Dicklesworthstone/cass_memory_system) | 0.2.x | See cm repo |

Both `cass` and `cm` must be on your `PATH` or specified via environment variables.

## Quick Install

```bash
git clone https://github.com/krasmussen37/cass-cm-mcp.git
cd cass-cm-mcp
./install.sh
```

The installer:
1. Checks that Python 3.7+, `cass`, and `cm` are available
2. Copies `cass-cm-mcp` to `~/.local/bin/`
3. Prompts to configure each agent (Claude Code, Codex CLI, Gemini CLI)

### Configure specific agents

```bash
./install.sh --configure-claude    # Claude Code only
./install.sh --configure-codex     # Codex CLI only
./install.sh --configure-gemini    # Gemini CLI only
./install.sh --configure-all       # All three agents
```

### Manual Install

```bash
cp cass-cm-mcp ~/.local/bin/
chmod +x ~/.local/bin/cass-cm-mcp
```

Then configure your agents manually (see below).

## Agent Configuration

Each CLI agent stores MCP server config in a different format. The installer handles all three, but here's the manual setup for reference.

### Claude Code (`~/.claude.json`)

```json
{
  "mcpServers": {
    "cass-cm": {
      "command": "/home/you/.local/bin/cass-cm-mcp",
      "args": [],
      "env": {},
      "description": "Session search (cass) + procedural memory/playbook (cm)"
    }
  }
}
```

If `cass-cm-mcp` is on your PATH, you can use just `"command": "cass-cm-mcp"`.

See [`claude-code.json.example`](claude-code.json.example).

### Codex CLI (`~/.codex/config.toml`)

```toml
[mcp_servers.cass-cm]
command = "/home/you/.local/bin/cass-cm-mcp"
args = []
```

Codex uses TOML. Add this block anywhere in the file alongside your other `[mcp_servers.*]` entries.

See [`codex-config.toml.example`](codex-config.toml.example).

### Gemini CLI (`~/.gemini/settings.json`)

```json
{
  "mcpServers": {
    "cass-cm": {
      "command": "/home/you/.local/bin/cass-cm-mcp",
      "args": []
    }
  }
}
```

Gemini uses JSON like Claude Code but does not use the `env` or `description` fields. Merge the `cass-cm` entry into your existing `mcpServers` object.

See [`gemini-settings.json.example`](gemini-settings.json.example).

### Config format summary

| Agent | Config file | Format | MCP key |
|-------|------------|--------|---------|
| Claude Code | `~/.claude.json` | JSON | `mcpServers` |
| Codex CLI | `~/.codex/config.toml` | TOML | `[mcp_servers.*]` |
| Gemini CLI | `~/.gemini/settings.json` | JSON | `mcpServers` |

Restart agent sessions after configuration changes.

## Tools

### Session Search (cass)

| Tool | Description |
|------|-------------|
| `cass_search` | Search all coding agent session history. Returns brief abstracts with relevance scores. |
| `cass_expand` | Drill into a search hit to see full surrounding conversation messages. |
| `cass_timeline` | Activity timeline across all coding agents over a time period. |
| `cass_stats` | Statistics about indexed session data. |

### Procedural Memory (cm)

| Tool | Description |
|------|-------------|
| `cm_context` | Get relevant playbook rules and history for a task. Use before starting work. |
| `cm_playbook_list` | List all active playbook rules with confidence scores. |
| `cm_playbook_add` | Add a new lesson-learned rule to the playbook. |
| `cm_playbook_mark` | Give feedback (helpful/harmful) on a playbook rule. |
| `cm_reflect` | Auto-extract new playbook rules from recent sessions (slow, uses LLM). |
| `cm_doctor` | Health check for the memory system. |

## Two-Tier Search Workflow

Search results are intentionally compact (~63% smaller than raw cass output) to conserve agent context windows. The workflow:

1. **`cass_search`** returns brief abstracts: score, title, snippet, date, agent, workspace, and a location pointer (source_path + line_number)
2. Agent scans results and identifies promising hits
3. **`cass_expand`** drills into specific hits for full conversation context

This prevents a single search from consuming thousands of tokens of agent context.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CASS_BIN` | auto-detect from PATH | Path to `cass` binary |
| `CM_BIN` | auto-detect from PATH | Path to `cm` binary |
| `GEMINI_API_KEY` | - | Auto-bridged to `GOOGLE_GENERATIVE_AI_API_KEY` for cm reflect |
| `CASS_CM_MCP_DEBUG` | unset | Set to `1` to keep stderr open for troubleshooting |

## CLI Usage

```bash
cass-cm-mcp              # Start MCP server (reads JSON-RPC from stdin)
cass-cm-mcp --version    # Print version
cass-cm-mcp --help       # Print usage
```

## Troubleshooting

**"missing required binaries"** - cass or cm not found. Install them and ensure they're on your PATH, or set `CASS_BIN`/`CM_BIN` environment variables.

**cm_reflect fails** - Requires an LLM API key. Set `GEMINI_API_KEY` in your environment or in the MCP server's `env` config:
```json
"env": {
  "GEMINI_API_KEY": "your-key-here"
}
```

**Debug mode** - Set `CASS_CM_MCP_DEBUG=1` in the MCP env config to see stderr output for troubleshooting.

**Stale sessions** - Run `cass index` to re-index, or start `cass index --watch` for real-time indexing of new sessions.

## License

MIT - see [LICENSE](LICENSE).
