%% E4 - TRACK: Situational Awareness on Moving Ships from Drifting Balloons
% Seminar: End-to-End EMSO Modeling in MATLAB (tracking)
% Companion to "Low-Altitude Target Tracking with Terrain-Aware Multi-Radar
% Fusion" (Sensor Fusion and Tracking Toolbox).
%
% 15 minutes of operations: every 60 s the balloons collect a 20 s PDW
% window, geolocate every rotating emitter (pw.locateGroup) and hand the
% fixes -- with their covariances -- to a tracker. The balloons themselves
% move (altitude-steered station keeping, pw.simulateHAB); their GNSS
% positions at each window are used, as in a real system.
% Tracker: trackerGNN + constant-velocity Kalman filter when Sensor Fusion
% and Tracking Toolbox is installed; otherwise pw.trackCV.
% NOTIONAL parameters.

setupPaths;
scn0 = pw.defaultScenario();
rx = scn0.rx; nH = numel(scn0.habs); ref = scn0.origin;
emIdx = find(strcmp({scn0.emitters.id}, 'MAR-X1') | strcmp({scn0.emitters.id}, 'MAR-S1'));
tEnd = 900; dtWin = 60; winLen = 20;

%% 1. Balloon trajectories for the run (altitude-steered, 1 h lookahead)
trj = cell(1,nH);
for h = 1:nH
    trj{h} = pw.simulateHAB(scn0.habs(h).station, tEnd + winLen, struct('dt', 10));
end
habAt = @(h, t) interp1(trj{h}.t, trj{h}.lla, t);

%% 2. Collect -> geolocate -> track, window by window
useTB = pw.hasToolbox('fusion');
if useTB
    tracker = trackerGNN('FilterInitializationFcn', @initcvkf, ...
        'AssignmentThreshold', 60, 'ConfirmationThreshold', [2 3], ...
        'DeletionThreshold', [4 5]);
end
fix = struct('t',{},'id',{},'xy',{},'R',{},'truth',{});
tbTracks = struct('t',{},'id',{},'xy',{});
tWins = 0:dtWin:tEnd-winLen;
fprintf('%6s %-7s %9s %9s\n','t (s)','emitter','fix err','CEP50');
for w = 1:numel(tWins)
    t0 = tWins(w);
    scn = scn0;
    for h = 1:nH, scn.habs(h).lla = habAt(h, t0 + winLen/2); end
    habLLA = vertcat(scn.habs.lla);
    pdw = pw.generatePDWs(scn, t0, winLen, struct('emitters', emIdx, 'seed', 100 + w));
    C = cell(1,nH);
    for h = 1:nH, C{h} = pw.deinterleave(pdw, h, struct('rx', rx)); end
    G = pw.associateClusters(C);
    dets = {};
    for g = 1:numel(G)
        m = G(g).members; c1 = C{m(1,1)}(m(1,2));
        if c1.truth == 0 || size(m,1) < 3, continue; end
        id = pw.classifyEmitter(c1, scn.lib, rx);
        em = scn.emitters(strcmp({scn.emitters.id}, id));
        sol = pw.locateGroup(pdw, G(g), C, habLLA, rx, em.lla0(3));
        if isempty(sol), continue; end
        tMid = t0 + winLen/2;
        xy = pw.enu(ref, sol.lla); xy = xy(1:2);
        tr = pw.enu(ref, pw.emitterPosition(em, tMid)); tr = tr(1:2);
        R = sol.covENU(1:2,1:2) + (em.speed_mps*winLen/sqrt(12))^2*eye(2)/2;  % motion smear
        fix(end+1) = struct('t',tMid,'id',id,'xy',xy,'R',R,'truth',tr); %#ok<SAGROW>
        fprintf('%6.0f %-7s %7.0f m %7.0f m\n', tMid, id, norm(xy - tr), sol.cep50);
        if useTB
            dets{end+1} = objectDetection(tMid, [xy(:); 0], ...
                'MeasurementNoise', blkdiag(R, 1), 'ObjectAttributes', struct('ID', id)); %#ok<SAGROW>
        end
    end
    if useTB
        confirmed = tracker(dets, t0 + winLen/2);
        for q = 1:numel(confirmed)
            s = confirmed(q).State;
            tbTracks(end+1) = struct('t', t0 + winLen/2, 'id', confirmed(q).TrackID, ...
                'xy', [s(1) s(3)]); %#ok<SAGROW>
        end
    end
end

%% 3. Track each identified emitter (pw.trackCV; per-ID association)
ids = unique({fix.id});
figErr = figure('Name','E4 errors vs time');
figure('Name','E4 tracks'); hold on; grid on; axis equal
colors = lines(numel(ids));
fprintf('\n%-7s %6s %14s %14s\n','emitter','fixes','RMS fix err','RMS track err');
for q = 1:numel(ids)
    f = fix(strcmp({fix.id}, ids{q}));
    [~, o] = sort([f.t]); f = f(o);
    XY = vertcat(f.xy); TR = vertcat(f.truth);
    Rk = cat(3, f.R);
    trk = pw.trackCV([f.t].', XY, Rk, 0.05);
    efix = sqrt(sum((XY - TR).^2, 2)); etrk = sqrt(sum((trk.x(:,1:2) - TR).^2, 2));
    fprintf('%-7s %6d %12.0f m %12.0f m\n', ids{q}, numel(f), sqrt(mean(efix.^2)), ...
        sqrt(mean(etrk(3:end).^2)));
    plot(TR(:,1)/1e3, TR(:,2)/1e3, '-', 'Color', colors(q,:), 'LineWidth', 2);
    plot(XY(:,1)/1e3, XY(:,2)/1e3, '.', 'Color', colors(q,:), 'MarkerSize', 12);
    plot(trk.x(:,1)/1e3, trk.x(:,2)/1e3, '--', 'Color', colors(q,:), 'LineWidth', 1.2);
    text(TR(end,1)/1e3 + 1, TR(end,2)/1e3, ids{q});
    cur = gcf; figure(figErr); subplot(numel(ids),1,q);
    plot([f.t], efix, 'o', [f.t], etrk, '-', 'LineWidth', 1.2); grid on
    ylabel('error (m)'); title(sprintf('%s: fix error (o) vs track error (-)', ids{q}));
    if q == numel(ids), xlabel('time (s)'); end
    figure(cur);
end
for h = 1:nH
    xy = pw.enu(ref, trj{h}.lla);
    plot(xy(:,1)/1e3, xy(:,2)/1e3, 'k-');
    plot(xy(end,1)/1e3, xy(end,2)/1e3, 'k^', 'MarkerFaceColor', [0.2 0.6 1]);
end
xlabel('east (km)'); ylabel('north (km)');
title('Ship truth (solid), balloon fixes (dots), CV-KF tracks (dashed), balloon paths (black)');
if useTB
    fprintf('trackerGNN produced %d confirmed track updates (%d unique track IDs).\n', ...
        numel(tbTracks), numel(unique([tbTracks.id])));
end

%% 4. Take-aways
% * Fixes every 60 s at a few hundred meters, smoothed by a CV filter,
%   give ship tracks good enough for cueing and pattern-of-life.
% * Emitter identity (from E2) doubles as a track label -- data
%   association is easy while the radar stays on and unambiguous.
% * The balloons drift tens of km during operations; using their true
%   GNSS positions each window keeps geolocation unbiased. GNSS denial of
%   the balloons themselves is a real vulnerability worth a trade study.
