#!/usr/bin/env bash
# cass-cm-mcp installer
# Checks prerequisites, installs the MCP server, optionally configures
# Claude Code, Codex CLI, and/or Gemini CLI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="cass-cm-mcp"

# Colors (disabled if NO_COLOR set or not a terminal)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''
fi

info()  { echo -e "${GREEN}[ok]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $*"; }
fail()  { echo -e "${RED}[err]${NC} $*"; exit 1; }

usage() {
    echo "Usage: install.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  --configure-claude    Add MCP server to Claude Code (~/.claude.json)"
    echo "  --configure-codex     Add MCP server to Codex CLI (~/.codex/config.toml)"
    echo "  --configure-gemini    Add MCP server to Gemini CLI (~/.gemini/settings.json)"
    echo "  --configure-all       Configure all three agents"
    echo "  -h, --help            Show this help"
    echo
    echo "Without flags, the installer will prompt interactively (if running in a terminal)."
}

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
configure_claude=false
configure_codex=false
configure_gemini=false
flag_mode=false

for arg in "$@"; do
    case "$arg" in
        --configure-claude) configure_claude=true; flag_mode=true ;;
        --configure-codex)  configure_codex=true;  flag_mode=true ;;
        --configure-gemini) configure_gemini=true;  flag_mode=true ;;
        --configure-all)    configure_claude=true; configure_codex=true; configure_gemini=true; flag_mode=true ;;
        -h|--help)          usage; exit 0 ;;
        *)                  warn "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
echo -e "${BOLD}cass-cm-mcp installer${NC}"
echo

errors=0

# Python 3.7+
if command -v python3 &>/dev/null; then
    py_ver=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    py_major=$(echo "$py_ver" | cut -d. -f1)
    py_minor=$(echo "$py_ver" | cut -d. -f2)
    if (( py_major >= 3 && py_minor >= 7 )); then
        info "Python $py_ver"
    else
        warn "Python $py_ver found (need 3.7+)"
        errors=$((errors + 1))
    fi
else
    warn "Python 3 not found"
    errors=$((errors + 1))
fi

# cass
if command -v cass &>/dev/null; then
    cass_ver=$(cass --version 2>/dev/null || echo "unknown")
    info "cass ($cass_ver)"
else
    warn "cass not found - install from: https://github.com/Dicklesworthstone/coding_agent_session_search"
    errors=$((errors + 1))
fi

# cm
if command -v cm &>/dev/null; then
    cm_ver=$(cm --version 2>/dev/null || echo "unknown")
    info "cm ($cm_ver)"
else
    warn "cm not found - install from: https://github.com/Dicklesworthstone/cass_memory_system"
    errors=$((errors + 1))
fi

if (( errors > 0 )); then
    echo
    fail "Missing prerequisites. Install them and re-run this script."
fi

echo

# ---------------------------------------------------------------------------
# Install binary
# ---------------------------------------------------------------------------
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
info "Installed to $INSTALL_DIR/$SCRIPT_NAME"

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    warn "$INSTALL_DIR is not in your PATH. Add it:"
    echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
fi

FULL_CMD="$INSTALL_DIR/$SCRIPT_NAME"

# ---------------------------------------------------------------------------
# Interactive prompts (only if no flags were passed and we have a terminal)
# ---------------------------------------------------------------------------
if ! $flag_mode && [[ -t 0 ]]; then
    echo
    echo -e "${BOLD}Configure agent MCP servers:${NC}"

    read -rp "  Claude Code (~/.claude.json)?       [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]] && configure_claude=true

    read -rp "  Codex CLI   (~/.codex/config.toml)?  [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]] && configure_codex=true

    read -rp "  Gemini CLI  (~/.gemini/settings.json)? [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]] && configure_gemini=true
fi

# ---------------------------------------------------------------------------
# Configure Claude Code (~/.claude.json)
# ---------------------------------------------------------------------------
if $configure_claude; then
    claude_json="${HOME}/.claude.json"
    if [[ -f "$claude_json" ]]; then
        if python3 -c "
import json, sys
with open('$claude_json') as f:
    data = json.load(f)
if 'cass-cm' in data.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
            info "Claude Code: already configured"
        else
            python3 -c "
import json
with open('$claude_json') as f:
    data = json.load(f)
if 'mcpServers' not in data:
    data['mcpServers'] = {}
data['mcpServers']['cass-cm'] = {
    'command': '$FULL_CMD',
    'args': [],
    'env': {},
    'description': 'Session search (cass) + procedural memory/playbook (cm)'
}
with open('$claude_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
            info "Claude Code: added cass-cm to $claude_json"
        fi
    else
        python3 -c "
import json
data = {
    'mcpServers': {
        'cass-cm': {
            'command': '$FULL_CMD',
            'args': [],
            'env': {},
            'description': 'Session search (cass) + procedural memory/playbook (cm)'
        }
    }
}
with open('$claude_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        info "Claude Code: created $claude_json"
    fi
fi

# ---------------------------------------------------------------------------
# Configure Codex CLI (~/.codex/config.toml)
# ---------------------------------------------------------------------------
if $configure_codex; then
    codex_toml="${HOME}/.codex/config.toml"
    if [[ -f "$codex_toml" ]]; then
        if grep -q '^\[mcp_servers\.cass-cm\]' "$codex_toml" 2>/dev/null; then
            info "Codex CLI: already configured"
        else
            cat >> "$codex_toml" <<EOF

[mcp_servers.cass-cm]
command = "$FULL_CMD"
args = []
EOF
            info "Codex CLI: added cass-cm to $codex_toml"
        fi
    else
        mkdir -p "$(dirname "$codex_toml")"
        cat > "$codex_toml" <<EOF
[mcp_servers.cass-cm]
command = "$FULL_CMD"
args = []
EOF
        info "Codex CLI: created $codex_toml"
    fi
fi

# ---------------------------------------------------------------------------
# Configure Gemini CLI (~/.gemini/settings.json)
# ---------------------------------------------------------------------------
if $configure_gemini; then
    gemini_json="${HOME}/.gemini/settings.json"
    if [[ -f "$gemini_json" ]]; then
        if python3 -c "
import json, sys
with open('$gemini_json') as f:
    data = json.load(f)
if 'cass-cm' in data.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
            info "Gemini CLI: already configured"
        else
            python3 -c "
import json
with open('$gemini_json') as f:
    data = json.load(f)
if 'mcpServers' not in data:
    data['mcpServers'] = {}
data['mcpServers']['cass-cm'] = {
    'command': '$FULL_CMD',
    'args': []
}
with open('$gemini_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
            info "Gemini CLI: added cass-cm to $gemini_json"
        fi
    else
        mkdir -p "$(dirname "$gemini_json")"
        python3 -c "
import json
data = {
    'mcpServers': {
        'cass-cm': {
            'command': '$FULL_CMD',
            'args': []
        }
    }
}
with open('$gemini_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        info "Gemini CLI: created $gemini_json"
    fi
fi

echo
echo -e "${GREEN}Done!${NC} Restart agent sessions to pick up the new MCP server."
echo
echo "Verify:  $SCRIPT_NAME --version"
echo "Test:    echo '{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"initialize\",\"params\":{}}' | $SCRIPT_NAME"
