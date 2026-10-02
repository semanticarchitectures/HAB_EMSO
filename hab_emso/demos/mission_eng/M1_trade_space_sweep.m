%% M1 - Trade-Space Exploration of a HAB EMSO Constellation
% Seminar: Mission Engineering -- Optimizing for Cost and Performance:
%          Trade Space Exploration of System-of-Systems Architectures
%
% Mission: persistent geolocation of fixed-site, marine and airborne radar
% emitters over a 400 x 400 km littoral area of interest, from Philowave-
% class filter-bank detectors on altitude-steered balloons.
%
% Design variables (6)                       Levels swept here
%   number of balloons          nHAB         3 4 6 8
%   station-ring radius (km)    ringRadius   30 50 80
%   filter-bank channels        nChannels    16 32 64   (2-18 GHz)
%   inter-balloon clock (ns)    sigmaSync    10 30 100
%   direction-finding option    dfOption     0 1        (amp.-comparison DF)
%   altitude band (+- km)       altBandHalf  3 4        (bus capability)
% Objectives: minimize campaign cost, maximize EFFECTIVE geolocation
% coverage = coverage x P(>= 3 balloons on station). Constraint: payload
% SWaP (<= 4 kg, <= 25 W). The small interactions produce the
% "disproportionate outcomes" the abstract describes: e.g. DF only pays
% off with fewer, cheaper channels (SWaP), and extra balloons matter more
% for resilience than for accuracy.
% ALL COSTS AND PERFORMANCE PARAMETERS ARE NOTIONAL.

setupPaths;

%% 1. Station keeping depends only on the altitude band: compute once
bands = [3 4];
frac = zeros(size(bands));
for b = 1:numel(bands)
    tr = pw.simulateHAB([36.3 -75.1 20e3], 72*3600, ...
        struct('altBand', 20e3 + bands(b)*[-1e3 1e3], 'dt', 60));
    frac(b) = tr.fracOnStation;
    fprintf('altitude band +-%d km: on station %.0f%% of the time\n', bands(b), 100*frac(b));
end

%% 2. Full-factorial sweep
L.nHAB = [3 4 6 8]; L.ring = [30 50 80]; L.nCh = [16 32 64];
L.sync = [10 30 100]; L.df = [0 1]; L.band = bands;
[a,b,c,d,e,f] = ndgrid(1:4, 1:3, 1:3, 1:3, 1:2, 1:2);
nD = numel(a);
R = zeros(nD, 13);   % design vars (6) + metrics (7)
opts = struct('gridStep_km', 25);
fprintf('Evaluating %d designs...\n', nD); t0 = tic;
for i = 1:nD
    dsg = struct('nHAB', L.nHAB(a(i)), 'ringRadius_km', L.ring(b(i)), ...
        'nChannels', L.nCh(c(i)), 'sigmaSync_ns', L.sync(d(i)), ...
        'dfOption', L.df(e(i)), 'altBandHalf_km', L.band(f(i)));
    opts.stationFrac = frac(f(i));
    M = pw.evaluateDesign(dsg, opts);
    R(i,:) = [dsg.nHAB dsg.ringRadius_km dsg.nChannels dsg.sigmaSync_ns dsg.dfOption ...
        dsg.altBandHalf_km, M.cost_USD, M.effGeoCoverage, M.geoCoverage, ...
        M.perClass(1).coverGeo, M.perClass(2).coverGeo, M.perClass(3).coverGeo, M.feasible];
    if mod(i, 50) == 0, fprintf('  %d/%d (%.0f s)\n', i, nD, toc(t0)); end
end
cost = R(:,7)/1e6; eff = R(:,8); feas = R(:,13) > 0;

%% 3. Pareto front (min cost, max effective coverage) among feasible designs
idx = find(feas);
isPar = false(nD,1);
for i = idx.'
    dom = feas & cost <= cost(i) & eff >= eff(i) & (cost < cost(i) | eff > eff(i));
    isPar(i) = ~any(dom);
end
par = find(isPar); [~, o] = sort(cost(par)); par = par(o);

figure('Name','M1 trade space'); hold on; grid on
scatter(cost(~feas), eff(~feas), 12, [0.8 0.8 0.8], 'x');
scatter(cost(feas & R(:,5)==0), eff(feas & R(:,5)==0), 18, [0.2 0.5 0.9], 'o');
scatter(cost(feas & R(:,5)==1), eff(feas & R(:,5)==1), 18, [0.9 0.4 0.1], 's');
plot(cost(par), eff(par), 'k-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'y');
xlabel('90-day campaign cost ($M, notional)');
ylabel('effective geolocation coverage');
legend('infeasible (SWaP)', 'filter bank only', 'with DF option', 'Pareto front', ...
    'Location', 'southeast');
title(sprintf('%d designs: cost vs effective coverage', nD));

fprintf('\nPareto-optimal designs:\n');
fprintf('%5s %5s %5s %6s %3s %5s | %7s %6s %6s %6s %6s\n','nHAB','ring','nCh', ...
    'sync','DF','band','cost$M','eff','fixed','marine','air');
for i = par.'
    fprintf('%5d %5d %5d %6d %3d %5d | %7.2f %6.2f %6.2f %6.2f %6.2f\n', R(i,1:6), ...
        cost(i), eff(i), R(i,10), R(i,11), R(i,12));
end

%% 4. Main effects: how much does each variable move effective coverage?
names = {'nHAB','ring (km)','channels','sync (ns)','DF','band (+-km)'};
figure('Name','M1 main effects');
for v = 1:6
    subplot(2,3,v);
    lv = unique(R(feas,v));
    mu = arrayfun(@(x) mean(eff(feas & R(:,v) == x)), lv);
    plot(lv, mu, 'o-', 'LineWidth', 1.5); grid on; title(names{v});
    ylim([0 1]); if v == 1 || v == 4, ylabel('mean eff. coverage'); end
end

%% 5. Reading the results (with this notional model)
% * Altitude-band authority (a BUS capability) is a threshold effect:
%   +-3 km holds station ~45 % of the time, +-4 km ~95 %. Nothing on the
%   payload side compensates, so every good design buys the larger band.
% * The DF option is the ONLY lever for airborne (ESA) emitters. It
%   multiplies channel hardware, so it fits the SWaP limit only with fewer
%   channels: the front is "16 channels + DF", adding balloons for
%   resilience and airborne coverage.
% * 100 ns clocks sit on every Pareto point: at a 1 km goal, scan timing
%   carries the rotating emitters and TDOA precision adds little. Tighten
%   the fixed-site goal to ~100 m and the answer changes -- try
%   opts.cepGoal_m = [100 1000 25000].
% * CAUTION -- a missing objective: coverage does not score IDENTIFICATION.
%   1 GHz channels (16 across 2-18 GHz) put more emitters in each channel
%   and blur frequency-based ID in a dense environment. Before accepting
%   "16 channels", add an ID-confusion objective (e.g., expected number of
%   library emitters sharing a channel and PW band). Trade studies reward
%   whatever they measure.
