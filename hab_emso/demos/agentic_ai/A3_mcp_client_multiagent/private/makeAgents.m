function [planner, critic] = makeAgents(cfg, req)
%MAKEAGENTS Build planner and critic agents for the selected backend.
%   Each agent is a function handle so the review loop is backend-agnostic:
%     [design, rationale, nToolCalls] = planner(round, critique, log)
%     critiqueText = critic(design, rationale, metrics, pass, failures)
switch cfg.backend
    case 'offline'
        planner = @(r, critique, log) offlinePlanner(r, log);
        critic  = @(d, why, m, pass, fails) offlineCritic(d, m, pass, fails);
    otherwise
        [planner, critic] = makeLLMAgents(cfg, req);   % MATLAB + LLMs add-on
end
end
