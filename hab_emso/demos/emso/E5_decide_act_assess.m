%% E5 - DECIDE, ACT, ASSESS: Closing the EMSO Loop by Repositioning Balloons
% Seminar: End-to-End EMSO Modeling in MATLAB (adaptive response, assessment)
%
% The EMSO loop is sense -> understand -> decide -> act -> assess. Here the
% "act" is the balloons' own maneuver: altitude steering lets the
% commander reposition the constellation to improve geolocation on a
% priority emitter set. The loop:
%   ASSESS (before)  geolocate everything with the current constellation
%   DECIDE           score candidate station layouts with the accuracy
%                    bound (pw.geolocationCRLB) using which balloons can
%                    actually hear each emitter (pw.usableHABs)
%   ACT              command new stations; simulate the altitude-steered
%                    transit (pw.simulateHAB) -- this takes HOURS
%   ASSESS (after)   re-run sense/understand/geolocate at the new positions
% Priority for this vignette: the two inland fixed sites (weight 2), while
% keeping the ships covered (weight 1). NOTIONAL parameters.

setupPaths;
scn = pw.defaultScenario();
rx = scn.rx; nH = numel(scn.habs); ref = scn.origin;
lib = scn.lib; names = {scn.emitters.id};
isRot = arrayfun(@(e) strcmp(lib(e.typeIdx).scanType,'rotating'), scn.emitters);
weight = arrayfun(@(e) 1 + strcmp(lib(e.typeIdx).class,'fixed'), scn.emitters);

%% 1. ASSESS (before): end-to-end geolocation with the baseline ring
before = runChain(scn, 0);
fprintf('\nBEFORE (baseline ring, radius 45 km):\n'); printResults(before, names);

%% 2. DECIDE: candidate layouts scored by the accuracy bound
% Emitter positions used for planning = the fixes just obtained (not truth).
cand = struct('name',{},'center',{},'offsets',{});
ringOff = @(r) r*[sind(45:90:315).' cosd(45:90:315).'];
cand(end+1) = struct('name','A baseline ring',          'center',[0 0],     'offsets',ringOff(45e3));
cand(end+1) = struct('name','B ring 40 km west',        'center',[-40e3 0], 'offsets',ringOff(45e3));
cand(end+1) = struct('name','C wide ring 60 km west',   'center',[-60e3 0], 'offsets',ringOff(75e3));
cand(end+1) = struct('name','D E-W picket (coast/sea)', 'center',[-30e3 0], ...
    'offsets',[-80e3 40e3; 60e3 40e3; 60e3 -40e3; -80e3 -40e3]);
estLLA = nan(numel(names),3);
for i = 1:numel(before)
    if ~isempty(before(i).sol), estLLA(before(i).ie,:) = before(i).sol.lla; end
end
fprintf('\n%-26s', 'candidate'); fprintf('%9s', names{isRot}); fprintf('%10s\n','score');
score = zeros(1,numel(cand)); habCand = cell(1,numel(cand));
for c = 1:numel(cand)
    xy = bsxfun(@plus, cand(c).offsets, cand(c).center);
    [~, H] = pw.enu(ref, [xy zeros(nH,1)], 'inverse'); H(:,3) = 20e3;
    habCand{c} = H;
    fprintf('%-26s', cand(c).name);
    tot = 0;
    for ie = find(isRot)
        typ = lib(scn.emitters(ie).typeIdx);
        P = estLLA(ie,:); if any(isnan(P)), P = scn.emitters(ie).lla0; end
        [mOK, sOK] = pw.usableHABs(typ, P, H, rx);
        prm = struct('sigmaTDOA_s', sqrt(2)*rx.sigmaSync_s, 'sigmaAz_deg', 0.08);
        prm.usable = mOK; cS = pw.geolocationCRLB(H, P, 'scan', prm);
        prm.usable = sOK; cT = pw.geolocationCRLB(H, P, 'tdoa', prm);
        cep = 1/sqrt(1/cS^2 + 1/cT^2);
        fprintf('%8.0fm', cep);
        tot = tot + weight(ie)*min(cep, 5e3);     % cap: a lost fix costs 5 km
    end
    score(c) = tot/sum(weight(isRot));
    fprintf('%9.0fm\n', score(c));
end
[~, best] = min(score);
fprintf('DECISION: %s (weighted mean bound %.0f m vs %.0f m baseline)\n', ...
    cand(best).name, score(best), score(1));

%% 3. ACT: altitude-steered transit to the new stations
newStations = habCand{best};
tTransit = 12*3600;
arrive = nan(1,nH); trj = cell(1,nH);
for h = 1:nH
    trj{h} = pw.simulateHAB(newStations(h,:), tTransit, ...
        struct('lla0', scn.habs(h).lla, 'dt', 60, 'keepRadius', 20e3));
    k = find(trj{h}.dist < 20e3, 1);
    if ~isempty(k), arrive(h) = trj{h}.t(k); end
end
fprintf('\nTransit times to within 20 km of new station (h): %s\n', mat2str(round(arrive/360)/10));
tArr = max(arrive);
if isnan(tArr), tArr = tTransit; fprintf('(not all balloons arrived within 12 h)\n'); end

figure('Name','E5 repositioning'); hold on; grid on; axis equal
for h = 1:nH
    xy = pw.enu(ref, trj{h}.lla);
    plot(xy(:,1)/1e3, xy(:,2)/1e3, '-');
    o = pw.enu(ref, scn.habs(h).lla); n = pw.enu(ref, newStations(h,:));
    plot(o(1)/1e3, o(2)/1e3, 'k^'); plot(n(1)/1e3, n(2)/1e3, 'r^', 'MarkerFaceColor','r');
end
for ie = find(isRot)
    e = pw.enu(ref, scn.emitters(ie).lla0);
    plot(e(1)/1e3, e(2)/1e3, 'ks', 'MarkerFaceColor', [1 0.8 0.2]);
    text(e(1)/1e3 + 4, e(2)/1e3, names{ie});
end
xlabel('east (km)'); ylabel('north (km)');
title(sprintf('Balloon transits to %s (black: old, red: new stations)', cand(best).name));

%% 4. ASSESS (after): re-run the chain at the new positions and time
scn2 = scn;
for h = 1:nH
    k = find(trj{h}.t >= tArr, 1); if isempty(k), k = numel(trj{h}.t); end
    scn2.habs(h).lla = trj{h}.lla(k,:);
end
after = runChain(scn2, tArr);
fprintf('\nAFTER (%s, t = %.1f h):\n', cand(best).name, tArr/3600); printResults(after, names);

fprintf('\n%-8s %14s %14s\n','emitter','error before','error after');
for ie = find(isRot)
    b = before([before.ie] == ie); a = after([after.ie] == ie);
    eb = NaN; ea = NaN;
    if ~isempty(b), eb = b.err; end
    if ~isempty(a), ea = a.err; end
    fprintf('%-8s %12.0f m %12.0f m\n', names{ie}, eb, ea);
end

errB = nan(1,numel(names)); errA = errB;
for ie = find(isRot)
    b = before([before.ie] == ie); a = after([after.ie] == ie);
    if ~isempty(b), errB(ie) = b(1).err; end
    if ~isempty(a), errA(ie) = a(1).err; end
end
fixIdx  = find(isRot & weight == 2); shipIdx = find(isRot & weight == 1);
fprintf('\nFixed sites (priority): mean error %.0f m -> %.0f m\n', ...
    mean(errB(fixIdx)), mean(errA(fixIdx)));
fprintf('Ships:                  mean error %.0f m -> %.0f m\n', ...
    mean(errB(shipIdx)), mean(errA(shipIdx)));
for ie = shipIdx
    d = pw.groundRange(pw.emitterPosition(scn.emitters(ie), 0), ...
        pw.emitterPosition(scn.emitters(ie), tArr));
    fprintf('  %s is %.0f km from where it was when the decision was made.\n', names{ie}, d/1e3);
end
fprintf(['LESSON: the weighting did what was asked -- the priority fixed sites\n' ...
         'improved several-fold. The ships paid for it: the new ring sits farther\n' ...
         'from the sea lanes, and the ships moved during the multi-hour transit.\n' ...
         'Plan on track-predicted positions at arrival time (E4), make the\n' ...
         'priority trade explicit, and keep assessing -- one 32 s window is one sample.\n']);

%% 5. Discussion: what else would a commander decide here?
% * AIR-X1 remains unlocated by filter-bank-only balloons (E3). Options:
%   add amplitude-comparison DF to some payloads (Radar seminar R5,
%   Mission Engineering M1) or cue an airborne/surface sensor.
% * A continuous emitter (jammer, datalink) raises a channel's floor
%   (E1, Radar seminar R4) but yields no pulses for TDOA/scan timing;
%   power-difference-of-arrival across balloons is the fallback, with
%   much poorer accuracy.
% * Repositioning takes hours and depends on the winds; single-balloon
%   loss leaves 3 -- the minimum. Resilience vs cost is quantified in
%   Mission Engineering M1/M2.

% Helper functions runChain.m and printResults.m are in ./private
