function sol = geolocate(meas, habLLA, opts)
%PW.GEOLOCATE Emitter position from multi-HAB TDOA and/or scan-timing
%   measurements (hybrid weighted nonlinear least squares).
%   sol = pw.geolocate(meas, habLLA)
%   sol = pw.geolocate(meas, habLLA, opts)
%
%   Measurement types (meas(m).type)
%     'tdoa'  value = t_j - t_i (s) for the same pulse at HABs i and j.
%             Locus: one sheet of a hyperboloid with HABs i, j as foci.
%     'scan'  value = t_j - t_i (s) between mainbeam crossings of HABs i
%             and j in the SAME revolution of a rotating antenna, and
%             period = rotation period (s). The emitter antenna turned
%             360*value/period degrees between pointing at HAB i and HAB j,
%             so that is the angle HAB i - emitter - HAB j. Locus: a circular
%             arc through both HABs (inscribed-angle theorem). Needs no
%             phase or AOA hardware -- ideal for a filter-bank detector.
%
%   opts
%     alt          known emitter altitude (m) -> 2-D solve (default 0)
%     solveAlt     true -> 3-D solve (needs >= 3 independent meas)
%     center       [lat lon] search center (default HAB centroid)
%     searchRadius (m, default 350e3), gridStep (m, default 3e3)
%
%   Correlated errors (shared reference clock / reference burst) are
%   handled by whitening with the correlation from meas.group/sigShared.
%
%   sol fields: lla, covENU (2x2 or 3x3, m^2), cep50 (m), ellipse95 (semi
%     axes, m, and orientation deg), rotDir (for scan meas), chi2, dof,
%     residuals (normalized), converged
if nargin < 3, opts = struct(); end
if ~isfield(opts,'alt'),          opts.alt = 0; end
if ~isfield(opts,'solveAlt'),     opts.solveAlt = false; end
if ~isfield(opts,'searchRadius'), opts.searchRadius = 350e3; end
if ~isfield(opts,'gridStep'),     opts.gridStep = 3e3; end
if ~isfield(opts,'center'),       opts.center = mean(habLLA(:,1:2),1); end

M = numel(meas);
W = whitener(meas);
sol = struct('lla',nan(1,3),'covENU',nan(2),'cep50',NaN,'ellipse95',nan(1,3), ...
             'rotDir',0,'chi2',NaN,'dof',NaN,'residuals',[],'converged',false);
if M < 2, return; end
isScan = strcmp({meas.type}, 'scan');

% ---- coarse grid search (also resolves rotation direction) ----------------
ref = [opts.center 0];
g = -opts.searchRadius:opts.gridStep:opts.searchRadius;
[X, Y] = meshgrid(g, g);
[~, P] = pw.enu(ref, [X(:) Y(:) zeros(numel(X),1)], 'inverse');
P(:,3) = opts.alt;
dirCands = [1 -1]; if ~any(isScan), dirCands = 1; end
best = inf;
for d = dirCands
    dirs = d*ones(1,M);
    c = cost(meas, habLLA, P, dirs, W);
    [cmin, ib] = min(c);
    if cmin < best, best = cmin; x0 = P(ib,:); sol.rotDir = d*any(isScan); dBest = dirs; end
end

% ---- Levenberg-Marquardt refinement in local ENU ---------------------------
nx = 2 + opts.solveAlt;
x = zeros(nx,1); lam = 1e-3; h = 5;
res = @(xx) W*resid(meas, habLLA, toLLA(x0, xx, opts), dBest);
r = res(x);
for it = 1:50
    J = zeros(numel(r), nx);
    for q = 1:nx
        dx = zeros(nx,1); dx(q) = h;
        J(:,q) = (res(x+dx) - res(x-dx))/(2*h);
    end
    A = J.'*J; g1 = J.'*r;
    step = -(A + lam*diag(diag(A)+1e-12))\g1;
    rn = res(x + step);
    if sum(rn.^2) < sum(r.^2)
        x = x + step; r = rn; lam = max(lam/3, 1e-9);
        if norm(step) < 0.05, sol.converged = true; break; end
    else
        lam = lam*5;
        if lam > 1e8, break; end
    end
end
if ~sol.converged && it < 50, sol.converged = true; end
sol.lla = toLLA(x0, x, opts);
sol.residuals = r;
sol.chi2 = sum(r.^2); sol.dof = numel(r) - nx;
Cv = inv(J.'*J);
sol.covENU = Cv;
[V, D] = eig(Cv(1:2,1:2));
s = sqrt(max(diag(D),0));
sol.cep50 = 0.5887*(s(1)+s(2));                 % approximation
[~, imax] = max(s); vmaj = V(:,imax);
sol.ellipse95 = [sqrt(5.991)*max(s), sqrt(5.991)*min(s), ...
                 mod(atan2(vmaj(1), vmaj(2))*180/pi, 180)];   % major-axis bearing
end

% -------------------------------------------------------------------------
function lla = toLLA(x0, x, opts)
xyz = [x(1) x(2) 0];
if opts.solveAlt, xyz(3) = x(3); end
[~, lla] = pw.enu(x0, xyz, 'inverse');
if ~opts.solveAlt, lla(3) = opts.alt; end
end

function r = resid(meas, habLLA, P, dirs)
[pred, sig, isAng] = pw.predictMeas(meas, habLLA, P, dirs);
v = [meas.value];
per = ones(size(v)); for m = 1:numel(meas), if isAng(m), per(m) = meas(m).period; end, end
z = v; z(isAng) = mod(360*v(isAng)./per(isAng), 360);
d = z - pred;
d(isAng) = mod(d(isAng) + 180, 360) - 180;
r = (d./sig).';
end

function c = cost(meas, habLLA, P, dirs, W)
[pred, sig, isAng] = pw.predictMeas(meas, habLLA, P, dirs);
v = [meas.value];
per = ones(size(v)); for m = 1:numel(meas), if isAng(m), per(m) = meas(m).period; end, end
z = v; z(isAng) = mod(360*v(isAng)./per(isAng), 360);
d = bsxfun(@minus, z, pred);
d(:,isAng) = mod(d(:,isAng) + 180, 360) - 180;
c = sum((bsxfun(@rdivide, d, sig)*W.').^2, 2);
end

function W = whitener(meas)
% Whitening matrix for normalized residuals, from the correlation implied by
% shared error terms (meas.group / meas.sigShared). Falls back to identity.
M = numel(meas);
if ~isfield(meas,'group') || M == 0, W = eye(M); return; end
sig = [meas.sigma];
Cn = eye(M);
for a = 1:M
    for b = a+1:M
        if ~isempty(meas(a).group) && isequal(meas(a).group, meas(b).group)
            rho = meas(a).sigShared*meas(b).sigShared/(sig(a)*sig(b));
            Cn(a,b) = rho; Cn(b,a) = rho;
        end
    end
end
[L, p] = chol(Cn, 'lower');
if p ~= 0, W = eye(M); else, W = inv(L); end
end
