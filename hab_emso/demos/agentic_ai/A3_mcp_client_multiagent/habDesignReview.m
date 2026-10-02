%% A3 - MATLAB as the MCP Client: a Multi-Agent Design Review
% Seminar: Engineers in the Loop: Agentic AI Workflows with MATLAB
% Highlight: MATLAB MCP Client -- MATLAB orchestrates multiple external
%            LLMs as a multi-agent system that brainstorms AND executes.
%
% Task: design a balloon (HAB) EMSO constellation that meets requirements.
%   PLANNER  (LLM #1, tool-using) proposes a design; it may call the
%            evaluateHabDesign MCP tool (A2) to explore before proposing.
%   MATLAB   independently re-evaluates the proposal with the SAME tested
%            model and checks the requirements deterministically.
%            MATLAB -- not either LLM -- decides pass/fail.
%   CRITIC   (LLM #2, different model/provider, no tools) reviews the
%            verified numbers and the planner's rationale, and asks for one
%            change. Its critique goes back to the planner.
% Repeat until the requirements pass or the round budget is spent.
%
% Backends (cfg.backend):
%   "offline" - scripted planner/critic, no LLM needed (dry runs, no network)
%   "ollama"  - local/private models via Ollama (both agents)
%   "openai"  - OpenAI API (both agents)
%   "mixed"   - planner on OpenAI, critic on local Ollama (public + private)
% Tool source (cfg.toolSource):
%   "local"      - call pw.evaluateDesign directly (no server)
%   "prodserver" - A2 server on MATLAB Production Server via prodserver.mcp
%   "mcpclient"  - any streamable-HTTP MCP server via mcpHTTPClient
% Requires (online backends): "Large Language Models (LLMs) with MATLAB"
% add-on (>= 4.6); for "mcpclient", the "MATLAB MCP HTTP Client" add-on
% (R2025a+). NOTIONAL model values throughout.

setupPaths;
cfg = struct();
cfg.backend      = 'offline';              % 'offline' | 'ollama' | 'openai' | 'mixed'
cfg.toolSource   = 'local';                % 'local' | 'prodserver' | 'mcpclient'
cfg.endpoint     = 'http://localhost:9910/HabEmso/mcp';
cfg.plannerModel = 'gpt-4.1-mini';         % or an Ollama model, e.g. 'qwen2.5:14b'
cfg.criticModel  = 'llama3.1:8b';          % a different model / provider
cfg.maxRounds    = 6;
cfg.maxToolCallsPerRound = 4;

% Requirements (the "spec" MATLAB enforces)
req = struct('fixed', 0.95, 'marine', 0.80, 'airborne', 0.50, ...
             'effGeoCoverage', 0.75, 'maxCost_USD', 1.6e6);

log = designReviewLoop(cfg, req);

%% Summary
fprintf('\n=== Design review summary (%s backend, %s tools) ===\n', cfg.backend, cfg.toolSource);
for r = 1:numel(log)
    L = log(r);
    fprintf('Round %d: nHAB %d ring %g km, %d ch, %g ns, DF %d, band %g km -> %s ($%.2fM, eff %.2f)\n', ...
        r, L.design.nHAB, L.design.ringRadius_km, L.design.nChannels, L.design.sigmaSync_ns, ...
        L.design.dfOption, L.design.altBandHalf_km, upper(L.verdict), L.metrics.cost_USD/1e6, ...
        L.metrics.effGeoCoverage);
end
fid = fopen('designReview_log.json', 'w'); fprintf(fid, '%s', jsonencode(log)); fclose(fid);
fprintf('Full transcript: designReview_log.json\n');
