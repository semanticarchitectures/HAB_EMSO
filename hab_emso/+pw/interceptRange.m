function [Rmax, info] = interceptRange(typ, rx, habAlt_m, emAlt_m, lobe)
%PW.INTERCEPTRANGE Maximum range at which a HAB detects an emitter's pulses.
%   [Rmax, info] = pw.interceptRange(typ, rx, habAlt_m, emAlt_m, lobe)
%     typ    emitter type (scn.lib(i) or pw.emitterLibrary entry)
%     rx     receiver (pw.defaultReceiver)
%     lobe   'main' (default) or 'side'
%   Rmax = min(link-budget range, radio-horizon range) in meters.
%   info: eirp_dBm, sens_dBm, Rlink, Rhorizon, margin_dB_at_100km
%   One-way link:  Prx = EIRP + Grx - FSPL(R) - Lpol - Lfilt  >= sensitivity
%   This is the one-way advantage of an intercept receiver: the radar's own
%   detection of a target falls as R^4, the intercept as R^2.
if nargin < 5, lobe = 'main'; end
k = pw.const();
ch = pw.channelOf(typ.fc, rx);
if ch == 0
    Rmax = 0; info = struct('eirp_dBm',NaN,'sens_dBm',NaN,'Rlink',0, ...
        'Rhorizon',NaN,'margin_dB_at_100km',NaN,'note','carrier outside filter bank');
    return
end
G = typ.G_dBi; if strcmpi(lobe,'side'), G = G + typ.SLL_dB; end
eirp = 10*log10(typ.Ppeak_W*1e3) + G;
budget = eirp + rx.Grx_dBi - rx.Lpol_dB - rx.Lfilt_dB - rx.sens_dBm(ch);  % allowed FSPL
lambda = k.c/typ.fc;
Rlink = 10^(budget/20)*lambda/(4*pi);
Rhor = sqrt(2*k.kEff*k.Re*habAlt_m) + sqrt(2*k.kEff*k.Re*max(emAlt_m,0));
Rmax = min(Rlink, Rhor);
info.eirp_dBm = eirp; info.sens_dBm = rx.sens_dBm(ch);
info.Rlink = Rlink; info.Rhorizon = Rhor;
info.margin_dB_at_100km = budget - pw.fspl(typ.fc, 100e3);
info.note = '';
end
