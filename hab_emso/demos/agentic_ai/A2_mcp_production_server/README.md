# A2: governed MATLAB tools for AI agents (MCP Framework for MATLAB Production Server)

**Point for the audience:** in A1 the agent *writes* MATLAB code, which is flexible but must be reviewed. Here the agent can only *call* five reviewed, tested, versioned MATLAB functions. Their `arguments` blocks reject invalid inputs (for example, a 20-balloon design or an unknown emitter). This gives two governance models for the same engineering question.

| Tool | What it answers |
|---|---|
| `listEmitterTypes` | Which (notional) emitters exist and what are their parameters? |
| `habInterceptRange` | How far can a balloon hear an emitter, in its main beam or in its sidelobes? |
| `habGeolocationAccuracy` | What CEP50 can a ring of *N* balloons achieve on an emitter at a given position? |
| `evaluateHabDesign` | What are the cost, coverage and SWaP of a constellation design? |
| `identifyEmitter` | Which library emitter matches these PDW features? |

The server also carries two **MCP resources**: `emitter_library.json` and `receiver_notional.json`. The LLM reads real (notional) parameter values from them instead of guessing.

## Run order
1. `testToolsLocally`: calls every tool in plain MATLAB. **Run this first.**
2. `buildHabMcpServer("http://localhost:9910")`: builds the `HabEmso` archive and deploys it.
3. `walkthrough`: lists the tools, calls one, and gives the client URL and demo prompts.

## Requirements
- MATLAB R2025b or later
- MATLAB Compiler SDK
- MATLAB Production Server R2022a or later (the framework's development server works for a laptop demo)
- MCP Framework add-on
- A plain-HTTP MCP client, or the framework's STDIO bridge

## Status
Written against the framework's documented API and examples: `prodserver.mcp.build` with `example=`, `resource=`, `archive=` and `folder=`, plus `deploy`, `ping`, `list` and `call`. **It has not been executed**, because no MATLAB was available when this was built. The tool bodies are thin wrappers over the `pw` library, which *is* tested (`tests/runCoreTests`).
