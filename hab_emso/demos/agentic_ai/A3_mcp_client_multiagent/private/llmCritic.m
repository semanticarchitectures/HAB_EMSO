function txt = llmCritic(chat, d, why, m, pass, failures)
%LLMCRITIC Independent review of a MATLAB-verified design (no tools).
if pass, v = "PASS"; else, v = "FAIL: " + strjoin(string(failures), "; "); end
prompt = sprintf(['Design: %s\nPlanner rationale: %s\nMATLAB-computed metrics: %s\n' ...
    'MATLAB verdict: %s'], jsonencode(d), why, jsonencode(m), v);
txt = char(generate(chat, prompt));
end
