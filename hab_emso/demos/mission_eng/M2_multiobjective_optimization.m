%% M2 - Multi-Objective Optimization of the HAB Constellation
% Seminar: Mission Engineering -- trade space exploration through
%          multi-objective optimization
%
% M1 swept a coarse grid. Here a genetic algorithm (gamultiobj, Global
% Optimization Toolbox) searches the continuous design space for the
% Pareto set of three objectives:
%     f1 = campaign cost ($M)                 minimize
%     f2 = -effective geolocation coverage    minimize (i.e. maximize)
%     f3 = median CEP50 over all geolocatable points (km)  minimize
% subject to payload SWaP (mass <= 4 kg, power <= 25 W).
% Integer-valued variables (nHAB, nChannels, DF) are rounded inside the
% objective -- a common, simple approach. Without the toolbox, a
% seeded random search + Pareto filter is used instead.
% NOTIONAL parameters.

setupPaths;
%         nHAB  ring(km) nCh   sync(ns)  DF   band(+-km)
lb   =  [   3     25      8      5       0     3.0 ];
ub   =  [   8    120     64    100       1     4.5 ];
nv = numel(lb);

% station keeping vs altitude band, precomputed on a grid and interpolated
bandGrid = 3:0.25:4.5; fracGrid = zeros(size(bandGrid));
for i = 1:numel(bandGrid)
    tr = pw.simulateHAB([36.3 -75.1 20e3], 48*3600, ...
        struct('altBand', 20e3 + bandGrid(i)*[-1e3 1e3], 'dt', 60));
    fracGrid(i) = tr.fracOnStation;
end
fprintf('station-keeping fraction vs band: %s\n', mat2str(round(100*fracGrid)));

obj = @(x) habObjectives(x, bandGrid, fracGrid);
con = @(x) habConstraints(x);

%% Optimize
if pw.hasToolbox('gads')
    o = optimoptions('gamultiobj', 'PopulationSize', 40, 'MaxGenerations', 20, ...
        'Display', 'iter', 'UseVectorized', false);
    [X, F] = gamultiobj(obj, nv, [], [], [], [], lb, ub, con, o);
else
    fprintf('Global Optimization Toolbox not found: random search (300 designs).\n');
    pw.setSeed(3);
    Xall = bsxfun(@plus, lb, bsxfun(@times, rand(300, nv), ub - lb));
    Fall = zeros(300,3); ok = false(300,1);
    for i = 1:300
        Fall(i,:) = obj(Xall(i,:));
        c = con(Xall(i,:)); ok(i) = all(c <= 0);
    end
    Xall = Xall(ok,:); Fall = Fall(ok,:);
    nd = true(size(Fall,1),1);
    for i = 1:size(Fall,1)
        dom = all(bsxfun(@le, Fall, Fall(i,:)), 2) & any(bsxfun(@lt, Fall, Fall(i,:)), 2);
        nd(i) = ~any(dom);
    end
    X = Xall(nd,:); F = Fall(nd,:);
end

%% Report the Pareto set
[~, o] = sort(F(:,1)); X = X(o,:); F = F(o,:);
fprintf('\n%5s %6s %5s %6s %3s %5s | %7s %6s %9s\n','nHAB','ring','nCh','sync','DF','band', ...
    'cost$M','eff','medCEP km');
for i = 1:size(X,1)
    xr = roundDesign(X(i,:));
    fprintf('%5d %6.0f %5d %6.0f %3d %5.2f | %7.2f %6.2f %9.2f\n', xr, F(i,1), -F(i,2), F(i,3));
end

figure('Name','M2 Pareto set');
scatter3(F(:,1), -F(:,2), F(:,3), 40, double(X(:,5) >= 0.5), 'filled'); grid on
xlabel('cost ($M)'); ylabel('effective coverage'); zlabel('median CEP50 (km)');
title('Pareto set (color: DF option)'); view(35, 25);

%% Notes for the seminar
% * The optimizer rediscovers M1's structure (band threshold, DF + few
%   channels) and fills in the continuous knobs (ring radius, band).
% * The third objective (median accuracy) separates designs with similar
%   coverage: many-channel, fine-clock designs are the most accurate but
%   cost more; DF designs buy airborne coverage but their bearing-only
%   fixes are km-class, which pulls the median CEP up.
% * Swap in your own cost model, mission AOI, emitter set and CEP goals via
%   pw.evaluateDesign -- the optimizer does not care what is inside.

% Objective/constraint helpers habObjectives.m, habConstraints.m and
% roundDesign.m are in ./private
