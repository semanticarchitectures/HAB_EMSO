%% matlabAsMcpClient - MATLAB as the MCP client (+ an LLM that uses the tools)
% MATLAB connects to an MCP server over HTTP, lists its tools, lets an LLM
% decide which to call, and executes the calls -- the "reverse flow".
%
% IMPORTANT: the MATLAB MCP HTTP Client connects to STREAMABLE-HTTP MCP
% servers. It cannot talk to the official MATLAB MCP Server (that server
% uses stdio and is meant for AI apps such as Claude). Typical targets:
%   * your own tools on MATLAB Production Server (MCP Framework, A2 in the
%     seminar package) -- that framework documents PLAIN HTTP, so test the
%     pairing; if it fails use prodserver.mcp.list/call instead (see A3)
%   * any other HTTP MCP server your organization runs
% Requires MATLAB R2025a+, "MATLAB MCP HTTP Client" and "Large Language
% Models (LLMs) with MATLAB" (>= 4.6) add-ons.

endpoint = "http://localhost:9910/HabEmso/mcp";   % <-- your server
useLocalModel = true;                             % Ollama (private) vs OpenAI

%% 1. Connect and inspect the tools
client = mcpHTTPClient(endpoint);
names = cellfun(@(t) string(t.name), client.ServerTools);
disp("Tools on " + endpoint + ":"); disp(names.');

%% 2. Give the tools to an LLM
tools = openAIFunction(client.ServerTools);
if useLocalModel
    llm = ollamaChat("qwen2.5:14b", "You are an EMSO systems engineer. Use the tools for every number.", Tools=tools);
else
    llm = openAIChat("You are an EMSO systems engineer. Use the tools for every number.", ...
        ModelName="gpt-4.1-mini", Tools=tools);
end

%% 3. Ask a question; execute tool calls until the model answers
history = messageHistory;
history = addUserMessage(history, ...
    "How far away can a 20 km balloon hear the MAR-X1 radar in its sidelobes, " + ...
    "and what does that mean for TDOA geolocation with balloons ~80 km apart?");
for step = 1:6
    [txt, resp] = generate(llm, history);
    if ~isfield(resp, "tool_calls") || isempty(resp.tool_calls), break; end
    history = addResponseMessage(history, resp);
    for c = 1:numel(resp.tool_calls)
        call = resp.tool_calls(c);
        fprintf("[tool] %s %s\n", call.function.name, string(jsonencode(call.function.arguments)));
        result = callTool(client, call.function);          % executed by MATLAB
        id = "call_" + c; if isfield(call, "id"), id = call.id; end
        history = addToolMessage(history, id, call.function.name, result);
    end
end
disp(txt)
