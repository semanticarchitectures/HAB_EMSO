%% A2 walkthrough - Governed MATLAB tools for AI agents via MCP
% Seminar: Engineers in the Loop: Agentic AI Workflows with MATLAB
% Highlight: MCP Framework for MATLAB Production Server
%
% Contrast with A1: there, the agent WRITES new MATLAB code every time.
% Here, the agent can only CALL reviewed, versioned, tested functions with
% validated inputs. Same question, two governance models.

%% 0. Prerequisites
% MATLAB R2025b+, MATLAB Compiler SDK, MATLAB Production Server (R2022a+)
% running at mpsServer, and the "MCP Framework for MATLAB Production
% Server" add-on. For a laptop demo, the framework's development server
% (see its DevAndTest example) works without a full MPS install.
if ~exist('mpsServer','var') || isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end
setupPaths;

%% 1. Test the functions locally first (the framework assumes they work)
testToolsLocally

%% 2. Build and deploy the multi-tool server with resources
[ctf, endpoint] = buildHabMcpServer(mpsServer);

%% 3. Inspect what an AI client will see
tools = prodserver.mcp.list(endpoint, "Tool");
cellfun(@(t) t.name, tools, 'UniformOutput', false)
tools{1}.description

%% 4. Call a tool directly, exactly as a client would
prodserver.mcp.call(endpoint, "habInterceptRange", "AIR-X1", 20, "side")

%% 5. Connect an AI client
% Point any MCP client that supports plain HTTP at:
%     <mpsServer>/HabEmso/mcp        e.g. http://localhost:9910/HabEmso/mcp
% Clients that only speak STDIO can use the framework's STDIO-to-HTTP
% bridge (see the framework docs: client configuration).
%
% Demo prompts (in the AI client):
%  1. "Which of the emitters in the HAB EMSO library can three balloons
%     geolocate using sidelobe TDOA from a 20 km balloon? Explain why."
%  2. "Compare evaluateHabDesign for 4 balloons at 45 km, 32 channels, 30 ns,
%     no DF, band 4 km against the same with DF and 16 channels. Which
%     would you recommend for a mission that includes airborne radars?"
%  3. "Identify an emitter at 9.4 GHz with 0.5 us pulses, 500 us PRI and a
%     2.5 s rotating scan."  (then: "How confident should I be?")
%  4. Try to break it: "Evaluate a design with 20 balloons."  The
%     arguments block rejects it -- the model cannot invent capability.
