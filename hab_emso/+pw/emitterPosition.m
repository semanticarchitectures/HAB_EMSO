function [lla, hdg] = emitterPosition(em, t)
%PW.EMITTERPOSITION Emitter position (and heading) at times t (s).
%   [lla, hdg] = pw.emitterPosition(em, t)
%   Motion model: constant speed along em.heading_deg, patrolling back and
%   forth over a leg of em.patrolLeg_m meters (Inf = straight line). Ships
%   and aircraft therefore stay in the area of interest over long mission
%   threads. Motion is computed in the tangent plane at lla0.
%   hdg is the instantaneous heading (deg) -- reversed on return legs.
t = t(:);
if em.speed_mps == 0
    lla = repmat(em.lla0, numel(t), 1); hdg = repmat(em.heading_deg, numel(t), 1);
    return
end
L = inf; if isfield(em,'patrolLeg_m') && ~isempty(em.patrolLeg_m), L = em.patrolLeg_m; end
d = em.speed_mps*t;
if isfinite(L)
    ph = mod(d, 2*L);
    back = ph > L;
    s = ph; s(back) = 2*L - ph(back);
else
    back = false(size(d)); s = d;
end
u = [sind(em.heading_deg) cosd(em.heading_deg) 0];
[~, lla] = pw.enu(em.lla0, s*u, 'inverse');
lla(:,3) = em.lla0(3);
hdg = repmat(em.heading_deg, numel(t), 1);
hdg(back) = mod(em.heading_deg + 180, 360);
end
