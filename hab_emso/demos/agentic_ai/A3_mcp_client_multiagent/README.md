# A3: MATLAB as the MCP client (a multi-agent design review)

**Seminar highlight:** the reverse flow. MATLAB code acts as the client and orchestrates several external LLMs.

- **Planner** (LLM #1, tool-using) proposes a balloon-constellation design. It can call the A2 `evaluateHabDesign` MCP tool while it explores.
- **MATLAB** independently re-evaluates the proposal with the tested `pw` model and **decides pass or fail deterministically**.
- **Critic** (LLM #2, a different model or provider, with no tools) reviews the *verified* numbers and asks for one change.

The planner and critic can be a public and a private model (`cfg.backend = 'mixed'`: OpenAI planner, local Ollama critic). That covers the abstract's "public and private LLMs".

## Run
```matlab
setupPaths
habDesignReview        % edit cfg at the top: backend, toolSource, models
```
- **`backend = 'offline'`** (default) runs the whole loop with scripted agents and no network. Use it for dry runs, or as a fallback if the venue blocks model APIs.
- **`toolSource`:**
  - `local` calls the model directly.
  - `prodserver` calls the A2 server through `prodserver.mcp.call`, following the framework's MATLABOpenAI example.
  - `mcpclient` uses the MATLAB MCP HTTP Client (`mcpHTTPClient`). Note that it targets *streamable* HTTP MCP servers, while the Production Server framework documents *plain* HTTP. Test that pairing before relying on it, and use `prodserver` if it fails.

## Points for the audience
1. The LLMs brainstorm; MATLAB computes and decides. The final verdict never depends on model output.
2. Tool inputs are validated by A2's `arguments` blocks, so a hallucinated "20 balloons" is rejected with an error that goes back to the model.
3. The transcript (`designReview_log.json`) is an audit trail: every proposal, every verified number, every critique.

## Status
The offline loop is tested here (GNU Octave). The LLM and MCP paths are written against the documented APIs of LLMs with MATLAB (≥ 4.6: `openAIChat`, `ollamaChat`, `openAIFunction`, `messageHistory`, `generate`), MCP HTTP Client (`mcpHTTPClient`, `callTool`) and the MPS framework (`prodserver.mcp.list` and `call`), but **have not been executed**. Plan a dry run.
