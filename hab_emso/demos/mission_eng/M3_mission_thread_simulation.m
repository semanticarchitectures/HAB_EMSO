%% M3 - Dynamic Mission-Thread Simulation: Launch to Persistent EMSO
% Seminar: Mission Engineering -- dynamic simulation of platforms
%          executing a defined mission (activity-driven)
%
% Static trade metrics (M1/M2) assume a constellation already on station.
% A mission thread asks the operational questions: how long after launch
% until the first fix? How much of each emitter's ON time is geolocated?
% What happens during transit, and when an emitter only radiates briefly?
%
% Each balloon runs a simple activity sequence (the executable analogue of
% an activity diagram -- see M4 for a System Composer architecture):
%     PreLaunch -> Ascent -> Transit -> OnStation
% Emitters follow activity schedules (radiate / silent). Every 5 minutes
% the geolocation accuracy bound is evaluated with the balloons' ACTUAL
% positions and the set of balloons that can hear each emitter.
% Two designs from the M1 Pareto front are compared. NOTIONAL values.

setupPaths;
scn = pw.defaultScenario(); lib = scn.lib; rx0 = scn.rx;
names = {scn.emitters.id};
launchSite = [36.85 -76.05 0];              % notional coastal launch site
tEnd = 24*3600; dt = 300; t = 0:dt:tEnd; nT = numel(t);
goal = [1000 1000 25000];                    % CEP goals: fixed, marine, air (m)

% emitter activity schedules [on off] in hours
sched = { [0 6; 8 24], [10 12; 16 17], [0 24], [12 20], [9 10.5; 14 15.5] };
isOn = false(numel(names), nT);
for ie = 1:numel(names)
    S = sched{ie};
    for r = 1:size(S,1), isOn(ie, t >= S(r,1)*3600 & t < S(r,2)*3600) = true; end
end

designs = { struct('name','4 HAB, filter bank only','nHAB',4,'ring',45,'df',0,'nCh',32), ...
            struct('name','6 HAB, 16 ch + DF',       'nHAB',6,'ring',80,'df',1,'nCh',16) };

for dI = 1:numel(designs)
    D = designs{dI};
    rx = pw.defaultReceiver(D.nCh);
    s2 = pw.defaultScenario(D.nHAB);
    % stations on the design ring
    st = zeros(D.nHAB,3);
    for i = 1:D.nHAB
        ang = 45 + (i-1)*360/D.nHAB;
        [~, l] = pw.enu(scn.origin, D.ring*1e3*[sind(ang) cosd(ang) 0], 'inverse');
        st(i,:) = [l(1:2) 20e3];
    end

    %% Balloon activity sequence: PreLaunch -> Ascent -> Transit -> OnStation
    tLaunch = (0:D.nHAB-1)*1800;             % one launch every 30 min
    tAscent = 1.5*3600;                      % to float altitude
    pos = nan(D.nHAB, 3, nT); state = cell(D.nHAB, nT);
    for i = 1:D.nHAB
        tFloat = tLaunch(i) + tAscent;
        tr = pw.simulateHAB(st(i,:), tEnd - tFloat, ...
            struct('lla0', [launchSite(1:2) 20e3], 'dt', 60, 'keepRadius', 30e3));
        for k = 1:nT
            if t(k) < tLaunch(i)
                state{i,k} = 'PreLaunch';
            elseif t(k) < tFloat
                state{i,k} = 'Ascent';
            else
                p = interp1(tr.t, tr.lla, min(t(k) - tFloat, tr.t(end)));
                pos(i,:,k) = p;
                if pw.groundRange(p, st(i,:)) < 30e3
                    state{i,k} = 'OnStation';
                else
                    state{i,k} = 'Transit';
                end
            end
        end
    end

    %% Evaluate geolocation quality over time
    cep = inf(numel(names), nT);
    for k = 1:nT
        av = find(~isnan(squeeze(pos(:,1,k))));
        if numel(av) < 2, continue; end
        H = squeeze(pos(av,:,k)); if isvector(H), H = H(:).'; end
        for ie = find(isOn(:,k)).'
            em = scn.emitters(ie); typ = lib(em.typeIdx);
            P = pw.emitterPosition(em, t(k));
            [mOK, sOK] = pw.usableHABs(typ, P, H, rx);
            prm = struct('sigmaTDOA_s', sqrt(2)*rx.sigmaSync_s, 'sigmaAz_deg', 0.08, ...
                'sigmaAOA_deg', 6);
            c = inf;
            if strcmp(typ.scanType,'rotating')
                prm.usable = mOK; cS = pw.geolocationCRLB(H, P, 'scan', prm);
                c = 1/sqrt(1/c^2 + 1/cS^2);
            end
            prm.usable = sOK; cT = pw.geolocationCRLB(H, P, 'tdoa', prm);
            c = 1/sqrt(1/c^2 + 1/cT^2);
            if D.df
                prm.usable = mOK; cA = pw.geolocationCRLB(H, P, 'aoa', prm);
                c = 1/sqrt(1/c^2 + 1/cA^2);
            end
            cep(ie,k) = c;
        end
    end

    %% Mission metrics
    cls = arrayfun(@(e) find(strcmp({'fixed','marine','airborne'}, lib(e.typeIdx).class)), scn.emitters);
    fprintf('\n=== %s ===\n', D.name);
    onSt = cellfun(@(s) strcmp(s,'OnStation'), state);
    kAll = find(sum(onSt,1) == D.nHAB, 1);
    if isempty(kAll)
        fprintf('Constellation never fully on station in 24 h\n');
    else
        fprintf('All balloons on station at %.1f h after first launch\n', t(kAll)/3600);
    end
    fprintf('%-8s %12s %16s %18s\n','emitter','ON (h)','first fix (h)','ON time fixed (%)');
    for ie = 1:numel(names)
        ok = isOn(ie,:) & cep(ie,:) < goal(cls(ie));
        kf = find(ok, 1);
        ff = NaN; if ~isempty(kf), ff = t(kf)/3600; end
        fprintf('%-8s %12.1f %16.1f %18.0f\n', names{ie}, nnz(isOn(ie,:))*dt/3600, ff, ...
            100*nnz(ok)/max(nnz(isOn(ie,:)),1));
    end

    %% Timeline plot (activity bars colored by fix quality)
    figure('Name', ['M3 timeline - ' D.name]);
    subplot(2,1,1); hold on
    for ie = 1:numel(names)
        on = isOn(ie,:); good = on & cep(ie,:) < goal(cls(ie));
        plot(t(on)/3600, ie*ones(1,nnz(on)), 's', 'Color', [0.75 0.75 0.75], 'MarkerSize', 4);
        plot(t(good)/3600, ie*ones(1,nnz(good)), 's', 'Color', [0 0.6 0], ...
            'MarkerFaceColor', [0 0.6 0], 'MarkerSize', 4);
    end
    set(gca, 'YTick', 1:numel(names), 'YTickLabel', names); ylim([0.5 numel(names)+0.5]);
    xlim([0 24]); grid on; title([D.name ': emitter ON (grey) and geolocated to goal (green)']);
    subplot(2,1,2);
    stairs(t/3600, sum(onSt,1), 'LineWidth', 1.5); grid on; xlim([0 24]);
    ylim([0 D.nHAB + 0.5]); xlabel('hours after first launch'); ylabel('balloons on station');
end

%% Take-aways
% * Time-to-first-fix is dominated by ascent + transit from the launch site,
%   not by sensing: the launch site and launch cadence are mission levers.
% * Brief emitters (a 1.5 h aircraft sortie) are only geolocated if the
%   right balloons are in place at that moment -- a coverage-over-time
%   metric that static trade studies (M1/M2) cannot show.
% * The DF design turns the airborne sorties green; the filter-bank-only
%   design never does, whatever the balloon count.
