%% E3 - GEOLOCATE: Multi-HAB TDOA + Scan-Timing Geolocation
% Seminar: End-to-End EMSO Modeling in MATLAB (passive geolocation)
% Companion to "Target Localization in Active and Passive Radar" (TOA/TDOA)
% and "Passive Bistatic Radar Localization Using OFDM" (TDOA + AOA).
%
% Filter-bank balloons have no AOA, so two measurement types are used:
%  * TDOA       - same pulse heard at >= 3 balloons (needs sidelobe
%                 intercepts); limited by inter-balloon clock error
%  * SCAN TIMING - time between a rotating beam sweeping balloon i and
%                 balloon j = angle i-emitter-j (inscribed-angle locus);
%                 needs only mainbeam intercepts; no phase, no AOA hardware
% Constant-PRI radars make TDOA ambiguous (several peaks k*PRI apart);
% the scan-timing fix picks the right one (two-stage pw.locateGroup).
% NOTIONAL parameters.

setupPaths;
scn = pw.defaultScenario();
rx = scn.rx; nH = numel(scn.habs); names = {scn.emitters.id};
habLLA = vertcat(scn.habs.lla);

%% 1. Sense and understand (as in E2)
pdw = pw.generatePDWs(scn, 0, 32);
C = cell(1,nH);
for h = 1:nH, C{h} = pw.deinterleave(pdw, h, struct('rx', rx)); end
G = pw.associateClusters(C);

%% 2. Geolocate every associated emitter
res = struct('id',{},'truth',{},'sol',{},'info',{},'err',{});
fprintf('%-7s %-8s %-7s %5s %5s %9s %9s %10s\n','emitter','method','scan','nScan','nTDOA', ...
    'error(m)','CEP50(m)','chi2/dof');
for g = 1:numel(G)
    m = G(g).members;
    c1 = C{m(1,1)}(m(1,2));
    if c1.truth == 0, continue; end
    em = scn.emitters(c1.truth); typ = scn.lib(em.typeIdx);
    id = pw.classifyEmitter(c1, scn.lib, rx);
    % known-altitude constraint: sea level for ships, site height for fixed
    % sites (from the library/intel); airborne -> solve 3-D
    alt = em.lla0(3); if strcmp(typ.class,'airborne'), alt = NaN; end
    [sol, meas, info] = pw.locateGroup(pdw, G(g), C, habLLA, rx, alt);
    truthLLA = pw.emitterPosition(em, 16);
    if isempty(sol)
        fprintf('%-7s %-8s %-7s   -- no fix: %s\n', id, 'none', G(g).scanType, info.reason);
        res(end+1) = struct('id',id,'truth',truthLLA,'sol',[],'info',info,'err',NaN); %#ok<SAGROW>
        continue
    end
    e = pw.groundRange(sol.lla, truthLLA);
    fprintf('%-7s %-8s %-7s %5d %5d %9.0f %9.0f %6.1f/%d\n', id, info.method, G(g).scanType, ...
        info.nScan, info.nTDOA, e, sol.cep50, sol.chi2, sol.dof);
    res(end+1) = struct('id',id,'truth',truthLLA,'sol',sol,'info',info,'err',e); %#ok<SAGROW>
end

%% 3. Map: balloons, truth, estimates and 95 % error ellipses (local ENU)
ref = scn.origin;
figure('Name','E3 geolocation map'); hold on; axis equal; grid on
hx = pw.enu(ref, habLLA);
plot(hx(:,1)/1e3, hx(:,2)/1e3, 'k^', 'MarkerFaceColor', [0.2 0.6 1], 'MarkerSize', 9);
for i = 1:numel(res)
    tx = pw.enu(ref, res(i).truth);
    plot(tx(1)/1e3, tx(2)/1e3, 'ko', 'MarkerSize', 8);
    text(tx(1)/1e3 + 5, tx(2)/1e3 + 5, res(i).id);
    if isempty(res(i).sol), continue; end
    sx = pw.enu(ref, res(i).sol.lla);
    plot(sx(1)/1e3, sx(2)/1e3, 'r+', 'MarkerSize', 10, 'LineWidth', 1.5);
    [V, D] = eig(res(i).sol.covENU(1:2,1:2));
    th = linspace(0, 2*pi, 100);
    ell = V*sqrt(5.991*D)*[cos(th); sin(th)];
    plot((sx(1) + 20*ell(1,:))/1e3, (sx(2) + 20*ell(2,:))/1e3, 'r-');
end
xlabel('east (km)'); ylabel('north (km)');
title('HABs (triangles), truth (o), estimates (+), 95% ellipses x20');

%% 4. Accuracy maps (Cramer-Rao-type bound) for the current constellation
g = -250e3:10e3:250e3; [X, Y] = meshgrid(g, g);
[~, P] = pw.enu(ref, [X(:) Y(:) zeros(numel(X),1)], 'inverse'); P(:,3) = 20;
prm = struct('sigmaTDOA_s', sqrt(2)*rx.sigmaSync_s, 'sigmaAz_deg', 0.08);
cT = pw.geolocationCRLB(habLLA, P, 'tdoa', prm);
cS = pw.geolocationCRLB(habLLA, P, 'scan', prm);
cB = pw.geolocationCRLB(habLLA, P, 'both', prm);
figure('Name','E3 CEP maps');
ttl = {'TDOA only (30 ns clocks)','scan timing only (0.08 deg)','hybrid'};
cc = {cT, cS, cB};
for q = 1:3
    subplot(1,3,q);
    imagesc(g/1e3, g/1e3, log10(reshape(cc{q}, size(X)))); axis xy equal tight
    caxis([1 4]); hold on; plot(hx(:,1)/1e3, hx(:,2)/1e3, 'k^', 'MarkerFaceColor','w');
    title(ttl{q}); xlabel('east (km)'); if q == 1, ylabel('north (km)'); end
end
colorbar; % log10(CEP50 m): 1 = 10 m, 2 = 100 m, 3 = 1 km, 4 = 10 km
fprintf(['\nCEP maps show log10(CEP50 in m). Accuracy is best inside the balloon\n' ...
         'ring and degrades with range outside it -- the fixed sites ~150 km west\n' ...
         'are why E5 considers repositioning balloons toward the coast.\n']);

%% 5. Optional cross-check with Phased Array System Toolbox tdoaposest
% (3-D TDOA solver; with 4 balloons at nearly the same altitude, the
% vertical is poorly observed, which is why pw.geolocate constrains the
% emitter altitude for surface emitters.)
if pw.hasToolbox('phased') && exist('tdoaposest','file')
    k = pw.const();
    i1 = find(strcmp({res.id}, 'FIX-C1'), 1);
    if ~isempty(i1) && ~isempty(res(i1).sol)
        tg = res(i1).truth;
        anc = pw.enu(ref, habLLA).';                   % 3-by-nH, meters
        tx  = pw.enu(ref, tg).';
        rr = sqrt(sum(bsxfun(@minus, anc, tx).^2, 1));
        tdoa = (rr(2:end) - rr(1)).'/k.c + sqrt(2)*rx.sigmaSync_s*randn(nH-1,1);
        try
            p3 = tdoaposest(tdoa, (sqrt(2)*rx.sigmaSync_s)^2*ones(nH-1,1), anc);
            fprintf('tdoaposest (3-D, unconstrained) error for FIX-C1: %.0f m horizontal, %.0f m vertical\n', ...
                norm(p3(1:2) - tx(1:2)), abs(p3(3) - tx(3)));
        catch err
            fprintf('tdoaposest cross-check skipped: %s\n', err.message);
        end
    end
end
