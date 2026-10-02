function txt = offlineCritic(d, m, pass, failures)
%OFFLINECRITIC Scripted stand-in for the critic LLM.
if pass
    txt = sprintf(['Meets every requirement at $%.2fM. Residual risks: only %d balloons ' ...
        '(losing %d leaves the minimum of 3); DF bearings give km-class aircraft fixes -- cueing ' ...
        'only; assumes perfect wind forecasts.'], m.cost_USD/1e6, d.nHAB, d.nHAB-3);
else
    txt = sprintf('Still failing: %s. Fix the largest shortfall first.', strjoin(failures, '; '));
end
end
