function [pass, failures] = checkRequirements(m, req)
%CHECKREQUIREMENTS Deterministic requirement check (MATLAB is the arbiter).
failures = {};
if ~m.feasible
    failures{end+1} = sprintf('payload SWaP infeasible (%.1f kg, %.0f W; limits 4 kg, 25 W)', ...
        m.payloadMass_kg, m.payloadPower_W);
end
cls = {'fixed','marine','airborne'};
for i = 1:3
    v = m.coverage.(cls{i});
    if v < req.(cls{i})
        failures{end+1} = sprintf('%s coverage %.2f < %.2f', cls{i}, v, req.(cls{i})); %#ok<AGROW>
    end
end
if m.effGeoCoverage < req.effGeoCoverage
    failures{end+1} = sprintf('effective coverage %.2f < %.2f (station keeping %.0f%%)', ...
        m.effGeoCoverage, req.effGeoCoverage, 100*m.fracOnStation);
end
if m.cost_USD > req.maxCost_USD
    failures{end+1} = sprintf('cost $%.2fM > $%.2fM', m.cost_USD/1e6, req.maxCost_USD/1e6);
end
pass = isempty(failures);
end
