function tr = simulateHAB(station, tEnd, opts)
%PW.SIMULATEHAB Altitude-steered HAB station keeping.
%   tr = pw.simulateHAB(station, tEnd)
%   tr = pw.simulateHAB(station, tEnd, opts)
%     station  [lat lon alt] desired station (alt = preferred float altitude)
%     tEnd     duration (s)
%   opts
%     dt            integration step (s), default 60
%     ctrlPeriod    re-plan interval (s), default 600
%     altBand       [min max] float altitude (m), default [15 23]*1e3
%     climbRate     max vertical speed (m/s), default 1.5
%     keepRadius    "on station" radius (m), default 50e3
%     lla0          start position (default = station)
%     wind          prm struct passed to pw.windField
%     steer         false -> free drift at station altitude (baseline)
%     horizon       look-ahead (s), default 3600
%
%   Controller (one-step look-ahead, in the spirit of the heuristics used by
%   altitude-steered balloons): every ctrlPeriod, for each candidate
%   altitude in the band, predict the position after `horizon` seconds
%   (drift in the current layer while climbing/descending, then ride the
%   candidate layer's wind) and command the altitude that ends closest to
%   the station. Wind forecasts are assumed perfect here; forecast error is
%   the main real-world degrader and is worth adding as a trade parameter.
%
%   tr fields: t, lla (N-by-3), dist (m from station), onStation (logical),
%              fracOnStation, cmdAlt
if nargin < 3, opts = struct(); end
d = struct('dt',60,'ctrlPeriod',600,'altBand',[15e3 23e3],'climbRate',1.5, ...
           'keepRadius',50e3,'lla0',station,'wind',struct(),'steer',true,'horizon',3600);
f = fieldnames(d);
for i = 1:numel(f), if ~isfield(opts, f{i}), opts.(f{i}) = d.(f{i}); end, end

t = (0:opts.dt:tEnd).';
N = numel(t);
lla = zeros(N,3); lla(1,:) = opts.lla0;
cmdAlt = zeros(N,1); cmdAlt(1) = opts.lla0(3);
cand = opts.altBand(1):250:opts.altBand(2);
alt = opts.lla0(3); target = alt;
for n = 2:N
    if opts.steer && mod(t(n-1), opts.ctrlPeriod) < opts.dt/2
        xy = pw.enu(station, [lla(n-1,1:2) 0]);          % position rel. station
        [vE, vN] = pw.windField(cand, t(n-1), opts.wind);
        [vE0, vN0] = pw.windField(alt, t(n-1), opts.wind);
        tClimb = min(abs(cand - alt)/opts.climbRate, opts.horizon);
        tRide  = opts.horizon - tClimb;
        % predicted position after the look-ahead horizon: drift in the
        % current layer while climbing, then ride the candidate layer
        pe = xy(1) + vE0*tClimb + vE.*tRide;
        pn = xy(2) + vN0*tClimb + vN.*tRide;
        score = -hypot(pe, pn);
        [~, ib] = max(score);
        target = cand(ib);
    end
    % vertical control
    dz = max(-opts.climbRate*opts.dt, min(opts.climbRate*opts.dt, target - alt));
    alt = alt + dz;
    [vE, vN] = pw.windField(alt, t(n-1), opts.wind);
    [~, nxt] = pw.enu(lla(n-1,:), [vE*opts.dt vN*opts.dt 0], 'inverse');
    lla(n,:) = [nxt(1:2) alt];
    cmdAlt(n) = target;
end
tr.t = t; tr.lla = lla; tr.cmdAlt = cmdAlt;
tr.dist = pw.groundRange(lla, repmat(station, N, 1));
tr.onStation = tr.dist <= opts.keepRadius;
tr.fracOnStation = mean(tr.onStation);
end
