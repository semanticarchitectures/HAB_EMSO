function [mainOK, sideOK, info] = usableHABs(typ, P, habLLA, rx, marginSide_dB)
%PW.USABLEHABS Which HABs can use an emitter at each candidate position.
%   [mainOK, sideOK] = pw.usableHABs(typ, P, habLLA, rx)
%     typ     emitter type (library entry)
%     P       N-by-3 emitter positions [lat lon alt]
%     habLLA  nHAB-by-3
%   mainOK(n,j)  HAB j receives the MAINBEAM above sensitivity at some
%                point in the scan (rotating: HAB inside the fan beam's
%                elevation coverage; ESA: inside the raster) -> scan timing
%                (rotating) or bearing/DF (with the DF option)
%   sideOK(n,j)  HAB j hears SIDELOBES above sensitivity + margin
%                (default 3 dB) on essentially every pulse -> TDOA
%   Both require radio line of sight over the 4/3 Earth.
if nargin < 5, marginSide_dB = 3; end
N = size(P,1); nH = size(habLLA,1);
mainOK = false(N,nH); sideOK = false(N,nH);
ch = pw.channelOf(typ.fc, rx);
info.channel = ch;
if ch == 0, return; end
for j = 1:nH
    Hj = repmat(habLLA(j,:), N, 1);
    [~, el, R] = pw.aer(P, Hj);
    vis = pw.isVisible(P, Hj);
    base = 10*log10(typ.Ppeak_W*1e3) + rx.Grx_dBi - pw.fspl(typ.fc, R) ...
           - rx.Lpol_dB - rx.Lfilt_dB - rx.sens_dBm(ch);
    switch typ.scanType
        case 'rotating'
            lo = typ.elCov_deg(1); hi = typ.elCov_deg(2);
            out = max(lo-el,0) + max(el-hi,0);
            Gm = typ.G_dBi + max(-12*(out/2).^2, typ.SLL_dB);
        case 'esa'
            inEl = el >= min(typ.esaEl_deg) - typ.elCov_deg & ...
                   el <= max(typ.esaEl_deg) + typ.elCov_deg;
            Gm = typ.G_dBi + typ.SLL_dB + (-typ.SLL_dB)*inEl;
    end
    mainOK(:,j) = vis & (base + Gm >= 0) & (Gm > typ.G_dBi + typ.SLL_dB + 3);
    sideOK(:,j) = vis & (base + typ.G_dBi + typ.SLL_dB >= marginSide_dB);
end
end
