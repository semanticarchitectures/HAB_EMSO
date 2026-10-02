#!/usr/bin/env bash
# Install the official MathWorks MATLAB MCP Server on macOS (Apple silicon)
# and register it with Claude Code, with the HAB custom tools.
#
#   ./install_matlab_mcp_macos.sh [--governed]
#
# --governed  : block the server's run-any-code tool (evaluate_matlab_code)
#               in Claude Code, so the agent can only call your custom tools
#               and the read-only/test tools.
# Prereqs: MATLAB R2021a+ installed; Claude Code installed (for step 4).
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.matlab-mcp"
BIN="$DEST/matlab-mcp-server"
EXT="$KIT/hab-tools.json"
GOVERNED=0; [[ "${1:-}" == "--governed" ]] && GOVERNED=1

echo "1/5 Downloading MATLAB MCP Server (macOS arm64) -> $BIN"
mkdir -p "$DEST"
curl -fL -o "$BIN" https://github.com/matlab/matlab-mcp-server/releases/latest/download/matlab-mcp-server-macos-arm64
chmod +x "$BIN"
xattr -d com.apple.quarantine "$BIN" 2>/dev/null || true   # binary is downloaded, not notarized via Finder
"$BIN" --version

echo "2/5 Locating MATLAB"
MLROOT=""
for d in /Applications/MATLAB_R20*.app; do [[ -d "$d" ]] && MLROOT="$d"; done   # newest by name
if [[ -z "$MLROOT" ]]; then echo "   MATLAB not found in /Applications; pass --matlab-root yourself."; else echo "   $MLROOT"; fi

echo "3/5 Installing the MATLAB MCP Server Toolbox (lets the server attach to a running MATLAB)"
if [[ -n "$MLROOT" ]]; then "$BIN" --setup-matlab --matlab-root="$MLROOT" || echo "   (setup-matlab failed; 'existing' session mode will be unavailable, 'new' still works)"; fi

echo "4/5 Registering with Claude Code"
if command -v claude >/dev/null 2>&1; then
  claude mcp remove matlab >/dev/null 2>&1 || true
  ARGS=(--extension-file="$EXT" --matlab-session-mode=auto --disable-telemetry=true)
  [[ -n "$MLROOT" ]] && ARGS+=(--matlab-root="$MLROOT")
  claude mcp add --scope user --transport stdio matlab -- "$BIN" "${ARGS[@]}"
  claude mcp list | grep -i matlab || true
  if [[ $GOVERNED -eq 1 ]]; then
    SETTINGS="$HOME/.claude/settings.json"
    python3 - "$SETTINGS" <<'PY'
import json, os, sys
p = sys.argv[1]; os.makedirs(os.path.dirname(p), exist_ok=True)
s = json.load(open(p)) if os.path.exists(p) else {}
perm = s.setdefault("permissions", {})
deny = perm.setdefault("deny", [])
rule = "mcp__matlab__evaluate_matlab_code"
if rule not in deny: deny.append(rule)
allow = perm.setdefault("allow", [])
if "mcp__matlab__hab_*" not in allow: allow.append("mcp__matlab__hab_*")
json.dump(s, open(p, "w"), indent=2)
print("   governed mode: denied", rule, "and auto-approved mcp__matlab__hab_* in", p)
PY
  fi
else
  echo "   Claude Code not found; skip. (Install it, then re-run this script.)"
fi

echo "4b  Writing a Claude Desktop config snippet (manual alternative to the .mcpb bundle)"
SNIP="$KIT/claude_desktop_config.snippet.json"
python3 - "$SNIP" "$BIN" "$EXT" "$MLROOT" <<'PY'
import json, sys
snip, binp, ext, mlroot = sys.argv[1:5]
args = ["--extension-file=" + ext, "--matlab-session-mode=auto", "--disable-telemetry=true"]
if mlroot: args.append("--matlab-root=" + mlroot)
json.dump({"mcpServers": {"matlab": {"command": binp, "args": args}}}, open(snip, "w"), indent=2)
print("   wrote", snip)
PY

echo "5/5 Next steps"
cat <<TXT
  In MATLAB, once:   registerMcpToolPaths('/path/to/hab_emso')
  Optional, to let Claude use the MATLAB you already have open:
                     shareMATLABSession()     (or add it to startup.m)
  Claude Desktop:    see README.md, section "Claude Desktop" (uses the .mcpb bundle)
  Extension file:    $EXT
  Server binary:     $BIN
TXT
