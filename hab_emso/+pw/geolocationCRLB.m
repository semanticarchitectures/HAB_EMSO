function [cep, info] = geolocationCRLB(habLLA, P, types, prm)
%PW.GEOLOCATIONCRLB Cramer-Rao-type accuracy map for multi-HAB geolocation.
%   [cep, info] = pw.geolocationCRLB(habLLA, P, types, prm)
%     habLLA  nHAB-by-3 HAB positions
%     P       N-by-3 emitter positions to evaluate (known altitude)
%     types   'tdoa' | 'scan' | 'both' | 'aoa'
%             'aoa' = bearing-only triangulation (each usable HAB measures
%             the azimuth to the emitter with prm.sigmaAOA_deg; needs >= 2)
%     prm     sigmaTDOA_s   (default 42 ns: sqrt(2) x 30 ns clock error)
%             sigmaAz_deg   scan-timing angle error per HAB (default 0.08)
%             usable        N-by-nHAB logical: which HABs contribute at each
%                           point (default all). Use it to encode which HABs
%                           hear sidelobes (TDOA) or see the mainbeam (scan).
%   cep      N-by-1 CEP50 (m); Inf where the geometry is unobservable
%   info.sig1, info.sig2  semi-axes of the 1-sigma error ellipse (m)
%
%   Linearized (Fisher information) bound, with the reference-HAB
%   correlation included. Differences are taken against HAB 1 of the usable
%   set at each point.
if nargin < 4, prm = struct(); end
if ~isfield(prm,'sigmaTDOA_s'), prm.sigmaTDOA_s = 42e-9; end
if ~isfield(prm,'sigmaAz_deg'), prm.sigmaAz_deg = 0.08; end
if ~isfield(prm,'sigmaAOA_deg'), prm.sigmaAOA_deg = 6; end
nH = size(habLLA,1); N = size(P,1);
if ~isfield(prm,'usable'), prm.usable = true(N,nH); end
k = pw.const();
h = 20;                                    % finite-difference step (m)
cep = inf(N,1); info.sig1 = inf(N,1); info.sig2 = inf(N,1);

% range and azimuth from each point to each HAB, at P and at P +- dx, dy
[rng0, az0] = fields_(P, habLLA);
[~, Pe] = offsets(P, [h 0]);  [rE, aE] = fields_(Pe, habLLA);
[~, Pn] = offsets(P, [0 h]);  [rN, aN] = fields_(Pn, habLLA);
dR_dE = (rE - rng0)/h;  dR_dN = (rN - rng0)/h;                 % N-by-nH
dA_dE = wrap(aE - az0)/h; dA_dN = wrap(aN - az0)/h;            % deg/m

if strcmp(types,'aoa')
    % azimuth measured AT each HAB toward the emitter
    azH = zeros(N,nH); azHE = azH; azHN = azH;
    for j = 1:nH
        azH(:,j)  = pw.aer(repmat(habLLA(j,:),N,1), P);
        azHE(:,j) = pw.aer(repmat(habLLA(j,:),N,1), Pe);
        azHN(:,j) = pw.aer(repmat(habLLA(j,:),N,1), Pn);
    end
    dE = wrap(azHE - azH)/h; dN = wrap(azHN - azH)/h;
    for n = 1:N
        u = find(prm.usable(n,:));
        if numel(u) < 2, continue; end
        J = [dE(n,u).' dN(n,u).'];
        Fi = J.'*J/prm.sigmaAOA_deg^2;
        if rcond(Fi) < 1e-14, continue; end
        ev = sqrt(max(eig(inv(Fi)),0));
        info.sig1(n) = max(ev); info.sig2(n) = min(ev);
        cep(n) = 0.5887*(ev(1)+ev(2));
    end
    return
end

for n = 1:N
    u = find(prm.usable(n,:));
    if numel(u) < 3, continue; end
    Jt = []; Ja = [];
    r = u(1);
    for j = u(2:end)
        Jt(end+1,:) = [dR_dE(n,j)-dR_dE(n,r), dR_dN(n,j)-dR_dN(n,r)]/k.c; %#ok<AGROW>
        Ja(end+1,:) = [dA_dE(n,j)-dA_dE(n,r), dA_dN(n,j)-dA_dN(n,r)];     %#ok<AGROW>
    end
    m = numel(u)-1;
    Cc = eye(m) + ones(m);                  % shared reference => correlation
    Fi = zeros(2);
    if any(strcmp(types, {'tdoa','both'}))
        Fi = Fi + Jt.'*((Cc*(prm.sigmaTDOA_s/sqrt(2))^2)\Jt);
    end
    if any(strcmp(types, {'scan','both'}))
        Fi = Fi + Ja.'*((Cc*(prm.sigmaAz_deg/sqrt(2))^2)\Ja);
    end
    if rcond(Fi) < 1e-14, continue; end
    ev = sqrt(max(eig(inv(Fi)),0));
    info.sig1(n) = max(ev); info.sig2(n) = min(ev);
    cep(n) = 0.5887*(ev(1)+ev(2));
end
end

function [rng, az] = fields_(P, habLLA)
N = size(P,1); nH = size(habLLA,1);
rng = zeros(N,nH); az = zeros(N,nH);
for j = 1:nH
    [a, ~, r] = pw.aer(P, repmat(habLLA(j,:), N, 1));
    rng(:,j) = r; az(:,j) = a;
end
end

function [xy, Q] = offsets(P, d)
% small local offset d = [dEast dNorth] (m), vectorized, spherical Earth
k = pw.const(); r = k.Re + P(:,3);
Q = [P(:,1) + d(2)./r*180/pi, P(:,2) + d(1)./(r.*cosd(P(:,1)))*180/pi, P(:,3)];
xy = d;
end

function d = wrap(d)
d = mod(d + 180, 360) - 180;
end
