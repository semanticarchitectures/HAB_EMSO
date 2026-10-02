function [d, why, nTools] = llmPlanner(chat, cfg, r, critique, log)
%LLMPLANNER One planner round: tool-calling loop, then a JSON proposal.
history = messageHistory;
if r == 1
    msg = "Propose your first design.";
else
    prev = log(end);
    msg = sprintf(['Your previous design was %s. MATLAB verified: %s. Verdict: %s. ' ...
        'Reviewer critique: %s Propose an improved design.'], jsonencode(prev.design), ...
        jsonencode(prev.metrics), upper(prev.verdict), critique);
end
history = addUserMessage(history, msg);
nTools = 0;
for k = 1:cfg.maxToolCallsPerRound + 1
    allowTools = nTools < cfg.maxToolCallsPerRound;
    if allowTools
        [txt, resp] = generate(chat, history);
    else
        [txt, resp] = generate(chat, history, ToolChoice="none");
    end
    if isfield(resp, 'tool_calls') && ~isempty(resp.tool_calls) && allowTools
        history = addResponseMessage(history, resp);
        for c = 1:numel(resp.tool_calls)
            call = resp.tool_calls(c);
            a = call.function.arguments;
            if ischar(a) || isstring(a), a = jsondecode(char(a)); end
            dd = struct('nHAB', a.nHAB, 'ringRadius_km', a.ringRadius_km, 'nChannels', a.nChannels, ...
                'sigmaSync_ns', a.sigmaSync_ns, 'dfOption', a.dfOption, 'altBandHalf_km', a.altBandHalf_km);
            try
                result = jsonencode(evaluateDesignJSON(dd, cfg, false));
            catch err
                result = "Tool error: " + err.message;   % e.g. out-of-range input rejected
            end
            id = "call_" + nTools; if isfield(call, 'id'), id = call.id; end
            history = addToolMessage(history, id, "evaluateHabDesign", result);
            nTools = nTools + 1;
            fprintf('  [planner tool call %d] %s\n', nTools, jsonencode(a));
        end
    else
        break
    end
end
j = regexp(char(txt), '\{.*\}', 'match', 'once');
p = jsondecode(j);
d = struct('nHAB', round(p.nHAB), 'ringRadius_km', p.ringRadius_km, ...
    'nChannels', p.nChannels, 'sigmaSync_ns', p.sigmaSync_ns, ...
    'dfOption', double(p.dfOption ~= 0), 'altBandHalf_km', p.altBandHalf_km);
why = ''; if isfield(p, 'rationale'), why = char(p.rationale); end
end
