#!/usr/bin/env bash
# cass-cm-mcp installer
# Checks prerequisites, installs the MCP server, optionally configures Claude Code.
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
# Install
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

# ---------------------------------------------------------------------------
# Optional Claude Code configuration
# ---------------------------------------------------------------------------
configure_claude=false
if [[ "${1:-}" == "--configure-claude" ]]; then
    configure_claude=true
elif [[ -t 0 ]]; then
    echo
    read -rp "Configure Claude Code (~/.claude.json)? [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]] && configure_claude=true
fi

if $configure_claude; then
    claude_json="${HOME}/.claude.json"
    if [[ -f "$claude_json" ]]; then
        # Check if already configured
        if python3 -c "
import json, sys
with open('$claude_json') as f:
    data = json.load(f)
servers = data.get('mcpServers', {})
if 'cass-cm' in servers:
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
            info "Claude Code already configured (cass-cm entry exists)"
        else
            # Add the MCP server entry
            python3 -c "
import json
with open('$claude_json') as f:
    data = json.load(f)
if 'mcpServers' not in data:
    data['mcpServers'] = {}
data['mcpServers']['cass-cm'] = {
    'command': '$INSTALL_DIR/$SCRIPT_NAME',
    'args': [],
    'env': {},
    'description': 'Session search (cass) + procedural memory/playbook (cm)'
}
with open('$claude_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
            info "Added cass-cm to $claude_json"
        fi
    else
        # Create new .claude.json
        python3 -c "
import json
data = {
    'mcpServers': {
        'cass-cm': {
            'command': '$INSTALL_DIR/$SCRIPT_NAME',
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
        info "Created $claude_json with cass-cm configuration"
    fi
fi

echo
echo -e "${GREEN}Done!${NC} Restart Claude Code sessions to pick up the new MCP server."
echo
echo "Verify:  $SCRIPT_NAME --version"
echo "Test:    echo '{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"initialize\",\"params\":{}}' | $SCRIPT_NAME"
