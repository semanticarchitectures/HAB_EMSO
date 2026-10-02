function [planner, critic] = makeLLMAgents(cfg, req)
%MAKELLMAGENTS Planner (tool-using) and critic LLM agents. MATLAB only.
%   Uses the "Large Language Models (LLMs) with MATLAB" add-on (openAIChat,
%   ollamaChat, openAIFunction, messageHistory) and, for tool calls, the A2
%   MCP server or the local model.
reqTxt = sprintf(['fixed-site coverage >= %.2f, marine >= %.2f, airborne (cueing) >= %.2f, ' ...
    'effective coverage >= %.2f, campaign cost <= $%.2fM, payload SWaP feasible ' ...
    '(<= 4 kg, <= 25 W)'], req.fixed, req.marine, req.airborne, req.effGeoCoverage, ...
    req.maxCost_USD/1e6);
plannerSys = sprintf(['You are a mission engineer designing a constellation of high-altitude ' ...
    'balloons carrying notional Philowave-class filter-bank RF detectors for EMSO. ' ...
    'Requirements: %s. Design variables and allowed values: nHAB 3-8 (integer), ' ...
    'ringRadius_km 20-120, nChannels one of 8/16/32/64, sigmaSync_ns 5-100, dfOption 0 or 1, ' ...
    'altBandHalf_km 3-4.5. You may call evaluateHabDesign to test ideas (at most %d calls). ' ...
    'Then answer ONLY with a JSON object with those six fields plus "rationale" (one sentence). ' ...
    'Prefer the cheapest design that meets every requirement.'], reqTxt, cfg.maxToolCallsPerRound);
criticSys = ['You are an independent reviewer on a design review board. You receive a ' ...
    'proposed balloon-constellation design, the planner''s rationale, and metrics COMPUTED BY ' ...
    'MATLAB (trust these numbers, never invent others) with a pass/fail verdict. In at most ' ...
    'three sentences: state the most important problem or risk, and request exactly one ' ...
    'concrete change to a design variable.'];

tools = makeTools(cfg);
switch cfg.backend
    case 'ollama'
        pChat = ollamaChat(cfg.plannerModel, plannerSys, Tools=tools);
        cChat = ollamaChat(cfg.criticModel, criticSys);
    case 'openai'
        pChat = openAIChat(plannerSys, ModelName=cfg.plannerModel, Tools=tools);
        cChat = openAIChat(criticSys, ModelName=cfg.criticModel);
    case 'mixed'   % public planner, private (local) critic
        pChat = openAIChat(plannerSys, ModelName=cfg.plannerModel, Tools=tools);
        cChat = ollamaChat(cfg.criticModel, criticSys);
    otherwise
        error('Unknown backend %s', cfg.backend);
end
planner = @(r, critique, log) llmPlanner(pChat, cfg, r, critique, log);
critic  = @(d, why, m, pass, fails) llmCritic(cChat, d, why, m, pass, fails);
end

function tools = makeTools(cfg)
switch cfg.toolSource
    case 'mcpclient'
        client = mcpHTTPClient(cfg.endpoint);
        tools = openAIFunction(client.ServerTools);
        tools = tools(strcmp([tools.FunctionName], "evaluateHabDesign"));
    case 'prodserver'
        tools = openAIFunction(prodserver.mcp.list(cfg.endpoint, "Tool"));
        tools = tools(strcmp([tools.FunctionName], "evaluateHabDesign"));
    otherwise   % local definition mirroring the A2 tool
        tools = openAIFunction("evaluateHabDesign", ...
            "Evaluate cost, coverage and SWaP of a balloon EMSO constellation design (notional model).");
        tools = addParameter(tools, "nHAB", type="integer", description="number of balloons, 3-8");
        tools = addParameter(tools, "ringRadius_km", type="number", description="station ring radius, 20-120 km");
        tools = addParameter(tools, "nChannels", type="integer", description="filter-bank channels: 8, 16, 32 or 64");
        tools = addParameter(tools, "sigmaSync_ns", type="number", description="inter-balloon clock error, 5-100 ns");
        tools = addParameter(tools, "dfOption", type="integer", description="1 = add direction finding, else 0");
        tools = addParameter(tools, "altBandHalf_km", type="number", description="altitude band half-width, 3-4.5 km");
end
end
