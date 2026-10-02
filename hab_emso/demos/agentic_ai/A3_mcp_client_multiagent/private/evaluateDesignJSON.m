function m = evaluateDesignJSON(d, cfg, trusted)
%EVALUATEDESIGNJSON Evaluate a design and return the metrics struct.
%   trusted = true  -> always the local, tested pw.evaluateDesign (MATLAB's
%                      own verification step; never delegated)
%   trusted = false -> use cfg.toolSource (what the planner's tool calls hit)
if nargin < 3, trusted = false; end
src = cfg.toolSource; if trusted, src = 'local'; end
switch src
    case 'local'
        M = pw.evaluateDesign(d, struct('gridStep_km', 25));
        m = struct('cost_USD', round(M.cost_USD), 'effGeoCoverage', M.effGeoCoverage, ...
            'coverage', struct('fixed', M.perClass(1).coverGeo, 'marine', M.perClass(2).coverGeo, ...
                               'airborne', M.perClass(3).coverGeo), ...
            'medianCEP_m', min(M.medianCEP_m, 1e6), 'fracOnStation', M.fracOnStation, ...
            'payloadMass_kg', M.payloadMass_kg, 'payloadPower_W', M.payloadPower_W, ...
            'feasible', logical(M.feasible));
    otherwise
        txt = callRemoteTool(cfg, 'evaluateHabDesign', d);
        m = jsondecode(char(txt));
end
end
