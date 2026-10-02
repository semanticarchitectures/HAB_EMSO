function log = designReviewLoop(cfg, req)
%DESIGNREVIEWLOOP Planner -> MATLAB verification -> critic, repeated.
%   Works in every backend; the LLM-specific parts live in makeAgents.m.
[planner, critic] = makeAgents(cfg, req);
log = struct('round', {}, 'design', {}, 'rationale', {}, 'metrics', {}, ...
             'verdict', {}, 'failures', {}, 'critique', {}, 'toolCalls', {});
critique = '';
for r = 1:cfg.maxRounds
    fprintf('\n--- Round %d ---\n', r);
    % 1. PLANNER proposes (may call the evaluate tool while exploring)
    [design, rationale, nTools] = planner(r, critique, log);
    fprintf('PLANNER proposes: %s\n  rationale: %s\n', designStr(design), rationale);
    % 2. MATLAB verifies -- trusted, deterministic, independent of the LLM
    metrics = evaluateDesignJSON(design, cfg, true);
    [pass, failures] = checkRequirements(metrics, req);
    if pass, verdict = 'pass'; else, verdict = 'fail'; end
    fprintf('MATLAB verdict: %s', upper(verdict));
    if ~pass, fprintf(' -- %s', strjoin(failures, '; ')); end
    fprintf('\n');
    % 3. CRITIC reviews the verified numbers
    critique = critic(design, rationale, metrics, pass, failures);
    fprintf('CRITIC: %s\n', critique);
    log(end+1) = struct('round', r, 'design', design, 'rationale', rationale, ...
        'metrics', metrics, 'verdict', verdict, 'failures', {failures}, ...
        'critique', critique, 'toolCalls', nTools); %#ok<AGROW>
    if pass
        fprintf('Requirements met in round %d.\n', r);
        break
    end
end
end

function s = designStr(d)
s = sprintf('nHAB %d, ring %g km, %d ch, clock %g ns, DF %d, band +-%g km', d.nHAB, ...
    d.ringRadius_km, d.nChannels, d.sigmaSync_ns, d.dfOption, d.altBandHalf_km);
end
