function [sol, meas, info] = locateGroup(pdw, grp, C, habLLA, rx, alt)
%PW.LOCATEGROUP Two-stage geolocation of one associated emitter group.
%   [sol, meas, info] = pw.locateGroup(pdw, grp, C, habLLA, rx, alt)
%     Stage 1  scan-timing fix (rotating emitters, >= 3 HABs in mainbeam).
%              Unambiguous but modest accuracy (hundreds of m).
%     Stage 2  TDOA from pulses heard at >= 3 HABs, using the stage-1 fix to
%              pick the right peak when a constant PRI makes TDOA ambiguous;
%              then a joint (hybrid) solve of all measurements.
%   info.method  'hybrid' | 'scan' | 'tdoa' | 'none'
%   info.rejected  measurements removed by the integrity (chi-square) check
%   info.reason  text explanation when no fix is produced (for reports)
%   alt          known emitter altitude (m) -- sea level for ships, site
%                elevation for fixed sites; for airborne emitters pass NaN to
%                solve in 3-D (needs more measurements).
if nargin < 6, alt = 0; end
opts = struct('alt', alt);
if isnan(alt), opts.solveAlt = true; opts.alt = 5000; end
info.method = 'none'; info.reason = ''; info.rejected = 0; sol = []; meas = [];

nMem = size(grp.members,1);
if nMem < 3
    info.reason = sprintf('only %d HAB(s) intercepted this emitter (need >= 3)', nMem);
    return
end
[mS, iS] = pw.buildMeasurements(pdw, grp, C, habLLA, rx, struct('useTDOA', false));
sol1 = [];
if numel(unique([[mS.i] [mS.j]])) >= 3
    sol1 = pw.geolocate(mS, habLLA, opts);
end
o2 = struct('useScan', false);
if ~isempty(sol1), o2.predictedLLA = sol1.lla; end
[mT, iT] = pw.buildMeasurements(pdw, grp, C, habLLA, rx, o2);
meas = [mS mT];
info.nScan = iS.nScan; info.nTDOA = iT.nTDOA; info.nAmbiguous = iT.nAmbiguous;
nT = numel(mT);
if ~isempty(sol1) && nT >= 1
    sol = pw.geolocate(meas, habLLA, opts); info.method = 'hybrid';
elseif ~isempty(sol1)
    sol = sol1; info.method = 'scan';
elseif nT >= 2 + opts.solveAlt
    sol = pw.geolocate(mT, habLLA, opts);  info.method = 'tdoa';
else
    if strcmp(grp.scanType,'rotating')
        info.reason = 'fewer than 3 HABs saw the mainbeam and too few common pulses for TDOA';
    else
        info.reason = ['electronically scanned emitter: no swept-beam timing, and its low ' ...
                       'sidelobes are not heard at >= 3 HABs simultaneously, so no TDOA'];
    end
    return
end
% ---- integrity check (RAIM-like): an implausible chi-square means at least
% one measurement is wrong (e.g., a TDOA on the wrong PRI peak). Drop the
% worst-fitting measurement and re-solve; never report a small CEP on an
% inconsistent solution.
info.rejected = 0;
while sol.dof >= 1 && sol.chi2/sol.dof > 4 && numel(meas) > 3
    r = sol.residuals(:);
    if numel(r) ~= numel(meas), break; end
    % whitened residuals mix measurements; score each by leave-one-out cost
    cst = inf(numel(meas),1);
    for q = 1:numel(meas)
        mm = meas([1:q-1 q+1:end]);
        sq = pw.geolocate(mm, habLLA, opts);
        if sq.dof >= 1, cst(q) = sq.chi2/sq.dof; end
    end
    [~, worst] = min(cst);
    meas(worst) = [];
    sol = pw.geolocate(meas, habLLA, opts);
    info.rejected = info.rejected + 1;
end
if sol.dof >= 1 && sol.chi2/sol.dof > 4
    info.reason = sprintf('inconsistent measurements (chi2/dof = %.1f): error estimate inflated', ...
        sol.chi2/sol.dof);
    inflate = sol.chi2/sol.dof;
    sol.covENU = sol.covENU*inflate; sol.cep50 = sol.cep50*sqrt(inflate);
elseif sol.dof < 1
    info.reason = 'solution is exactly determined (no redundancy); error estimate unreliable';
end
end
