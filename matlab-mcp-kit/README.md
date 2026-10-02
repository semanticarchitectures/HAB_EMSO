# Connect Claude to MATLAB over MCP (macOS, Apple silicon)

This kit gives you three connections:

| Connection | What it does | Transport |
|---|---|---|
| **Claude Code → MATLAB** | Official MathWorks MATLAB MCP Server: start MATLAB, run code, lint, run tests, **plus six HAB custom tools** | stdio (local) |
| **Claude Desktop → MATLAB** | The same server as a desktop extension | stdio (local) |
| **MATLAB → MCP servers** | MATLAB acts as the client and hands HTTP MCP tools to an LLM (`matlabAsMcpClient.m`) | HTTP |

The custom tools are defined in `hab-tools.json` and implemented by the wrappers in `mcp_tools/`, which call the tested `pw` library from the seminar package:
- `hab_list_emitters`
- `hab_intercept_range`
- `hab_geolocation_accuracy`
- `hab_evaluate_design`
- `hab_identify_emitter`
- `hab_run_core_tests`

To expose other MATLAB applications, add a wrapper and an entry in the same format (see "Adding your own tools" below).

## Prerequisites
- MATLAB R2021a or later in `/Applications`. R2023a or later is needed to attach to an already-open MATLAB.
- The seminar package unzipped (the `hab_emso` folder).
- Claude Code (for route 1) and/or Claude Desktop (for route 2).

## 1. Install the server and connect Claude Code (about 5 minutes)
```bash
cd matlab-mcp-kit
./install_matlab_mcp_macos.sh            # or: ./install_matlab_mcp_macos.sh --governed
```
The script does the following:
1. Downloads the arm64 server binary to `~/.matlab-mcp/`.
2. Clears the macOS quarantine flag.
3. Installs the MATLAB MCP Server Toolbox with `--setup-matlab`.
4. Registers the server with Claude Code at user scope, together with the extension file.
5. Writes `claude_desktop_config.snippet.json`, which you need for route 2.

Then, **once, in MATLAB:**
```matlab
cd matlab-mcp-kit
registerMcpToolPaths('/Users/<you>/…/hab_emso')   % adds the tool paths to startup.m
shareMATLABSession()                              % optional: let Claude use this open MATLAB
```
`registerMcpToolPaths` is needed because custom tools must be on the MATLAB path, and a MATLAB session that the server launches only runs `startup.m`.

**Check it:** run `claude mcp list` in a terminal and confirm that `matlab` shows as connected. Then ask Claude Code:
> *Use the matlab tools: how far can a 20 km balloon hear MAR-X1 in its sidelobes?*

Expected answer: about **24.8 km**. The first call starts MATLAB, so it can take 20–60 s.

### Governed mode (optional)
`--governed` adds `mcp__matlab__evaluate_matlab_code` to the `permissions.deny` list in `~/.claude/settings.json` and auto-approves `mcp__matlab__hab_*`. Claude can then call only your approved tools, plus the read-only lint, toolbox and test tools, and cannot run arbitrary MATLAB code. Remove the deny rule to restore full access.

## 2. Claude Desktop
**Recommended: the official bundle**
1. In **Settings → Extensions → Browse extensions**, install and enable the **Filesystem** extension, and allow your project folders.
2. Download `matlab-mcp-server.mcpb` from the [latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) and double-click it to install.
3. In **Settings → Extensions → MATLAB → Configure**, add `--extension-file=/…/matlab-mcp-kit/hab-tools.json` to the arguments, plus `--matlab-session-mode=auto` if you want it to attach to an open MATLAB.

**Alternative: manual configuration**, if the Configure panel doesn't accept the extension argument. Open **Settings → Developer → Edit Config** and merge the `mcpServers` block from `claude_desktop_config.snippet.json`, which the installer wrote with your real paths. Then restart Claude Desktop.

## 3. MATLAB as the MCP client
`matlabAsMcpClient.m` connects to an **HTTP** MCP server, gives its tools to a local (Ollama) or OpenAI model, and executes the model's tool calls. It needs:
- MATLAB R2025a or later
- The **MATLAB MCP HTTP Client** add-on
- **LLMs with MATLAB** 4.6 or later

It **cannot** connect to the official MATLAB MCP Server, which speaks stdio only. Point it at your Production Server tools (seminar demo A2) or another HTTP MCP server. The Production Server framework documents *plain* HTTP while this client expects *streamable* HTTP, so test that pairing. If it fails, use `prodserver.mcp.list` and `prodserver.mcp.call` as in demo A3.

## Adding your own tools
1. Write a MATLAB function that **prints** its result, ideally as `disp(jsonencode(...))`. The server returns command-window output, not return values.
2. Put it on the MATLAB path, either through `startup.m` or by extending `registerMcpToolPaths`.
3. Add a tool entry and a matching signature to `hab-tools.json`, or to a second file passed with another `--extension-file=`. Argument types are limited to `string`, `number`, `integer` and `boolean`, with **no arrays**, so pass lists as text as `hab_identify_emitter` does. The `input.order` list must equal the property names exactly.
4. Restart the server: `/mcp` in Claude Code, or restart Claude Desktop.

## Troubleshooting
- **"cannot be opened" or killed at launch:** run `xattr -d com.apple.quarantine ~/.matlab-mcp/matlab-mcp-server`.
- **Wrong MATLAB, or MATLAB not found:** pass `--matlab-root=/Applications/MATLAB_R20xxx.app`, then re-add the server.
- **Custom tool says "Undefined function":** the paths are missing. Re-run `registerMcpToolPaths` and restart the server.
- **Logs:** add `--log-level=debug --log-folder=/tmp/matlab-mcp-logs`.

## Security and licensing
- `evaluate_matlab_code` runs arbitrary code with your user rights. Keep approval prompts on, or use governed mode.
- MathWorks licenses the server for **single-user** use; a shared or central server needs MathWorks' agreement. For multi-user deployment, use the Production Server MCP Framework (demo A2).
- Telemetry is disabled by the installer (`--disable-telemetry=true`).
- **Tested:** the tool wrappers and the generated extension file (logic checked in GNU Octave).
- **Not tested:** the installer and the client registration, because no Mac or MATLAB was available here. Expect to adjust a path or two on the first run.
