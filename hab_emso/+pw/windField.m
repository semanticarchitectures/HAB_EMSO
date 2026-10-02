function [vE, vN] = windField(alt_m, t_s, prm)
%PW.WINDFIELD Notional stratospheric wind (m/s) vs altitude and time.
%   [vE, vN] = pw.windField(alt_m, t_s)
%   [vE, vN] = pw.windField(alt_m, t_s, prm)
%
%   Altitude-steered balloons (Loon-style) station-keep by moving up or down
%   into layers whose winds blow toward the station. This needs DIRECTIONAL
%   SHEAR: wind direction must change with altitude. The model:
%     direction(h,t) = dir0 + shear*(h - 15 km)/1 km + slow diurnal drift
%     speed(h,t)     = s0 + s1*sin(2*pi*(h-15km)/wl) + gusts
%   Default: ~40 deg of turning per km over 15-23 km (so the band spans
%   >270 deg of direction), 4-14 m/s. Real stratospheric winds are often
%   less favorable (e.g., strong zonal jets in winter), which is the main
%   risk to station-keeping and should be exercised in the trade study.
%   prm fields (optional): dir0_deg, shear_degPerKm, s0, s1, wl_m, drift_degPerHr
if nargin < 3, prm = struct(); end
d = struct('dir0_deg', 250, 'shear_degPerKm', 40, 's0', 9, 's1', 5, ...
           'wl_m', 5000, 'drift_degPerHr', 3);
f = fieldnames(d);
for i = 1:numel(f), if ~isfield(prm, f{i}), prm.(f{i}) = d.(f{i}); end, end
h = (alt_m - 15e3)/1e3;
dirDeg = prm.dir0_deg + prm.shear_degPerKm*h + prm.drift_degPerHr*t_s/3600 ...
         + 10*sin(2*pi*t_s/86400);
spd = max(prm.s0 + prm.s1*sin(2*pi*(alt_m-15e3)/prm.wl_m + t_s/20000), 1);
% "direction" is where the wind blows TOWARD (navigation convention)
vE = spd.*sind(dirDeg);
vN = spd.*cosd(dirDeg);
end
