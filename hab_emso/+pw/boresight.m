function [az, el, f, pri, info] = boresight(em, typ, t)
%PW.BORESIGHT Antenna pointing, carrier and PRI of an emitter at times t.
%   [az, el, f, pri, info] = pw.boresight(em, typ, t)
%     em   emitter instance (scn.emitters(i)); typ = scn.lib(em.typeIdx)
%     az   boresight azimuth (deg true).  el  boresight elevation (deg)
%          (rotating fan beams report el = NaN: coverage is elCov_deg)
%     f    carrier (Hz) in use.   pri  PRI in use for ESA dwells (s)
%     info.revIdx (rotating) or info.dwellIdx / azRel (ESA)
t = t(:);
switch typ.scanType
    case 'rotating'
        edges = [0; cumsum(em.revPeriods)];
        tt = mod(t, edges(end));                       % wrap long runs
        r  = discretize_(tt, edges);
        frac = (tt - edges(r)) ./ em.revPeriods(r);
        az = mod(em.az0_deg + typ.rotDir*360*frac, 360);
        el = nan(size(t));
        f  = repmat(typ.fc, size(t));
        pri = nan(size(t));
        info.revIdx = r;
    case 'esa'
        nAz = numel(typ.esaAz_deg); nEl = numel(typ.esaEl_deg);
        k   = floor((t + em.esaT0)/typ.esaDwell_s);    % global dwell counter
        pos = mod(k, nAz*nEl);
        iEl = floor(pos/nAz) + 1;
        iAz = mod(pos, nAz) + 1;
        % boustrophedon raster: reverse azimuth order on alternate bars
        rev = mod(iEl,2) == 0;
        iAz(rev) = nAz - iAz(rev) + 1;
        azRel = typ.esaAz_deg(iAz); azRel = azRel(:);
        [~, hdg] = pw.emitterPosition(em, t);            % array faces the flight direction
        az  = mod(hdg + azRel, 360);
        el  = typ.esaEl_deg(iEl); el = el(:);
        % pseudo-random frequency hop and PRI per dwell (deterministic)
        nf = numel(typ.fAgile); np = numel(typ.PRI_s);
        f   = typ.fAgile(mod(7*k + 3, nf) + 1); f = f(:);
        pri = typ.PRI_s(mod(5*k + floor(k/7), np) + 1); pri = pri(:);
        info.dwellIdx = k; info.azRel = azRel;
    otherwise
        error('pw:boresight', 'Unknown scanType %s', typ.scanType);
end
end

function idx = discretize_(x, edges)
% Portable replacement for discretize (bin index, right-open intervals).
idx = interp1(edges(:), (1:numel(edges)).', x, 'previous');
idx(isnan(idx)) = 1;
idx = min(max(idx,1), numel(edges)-1);
end
