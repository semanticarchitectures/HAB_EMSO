function scn = defaultScenario(nHAB, seed)
%PW.DEFAULTSCENARIO Notional littoral EMSO scenario used by all demos.
%   scn = pw.defaultScenario()        4 altitude-steered HABs, 5 emitters
%   scn = pw.defaultScenario(nHAB)    3..8 HABs on a ring around the AOI
%   scn = pw.defaultScenario(nHAB, seed)
%
%   Geography is notional: a coastline near 36N 75.5W is used only so the
%   scenario has land (fixed sites), sea (ships) and an air lane. No real
%   systems or sites are represented.
%
%   scn fields
%     origin      [lat lon 0] of the area of interest (AOI) center
%     rx          receiver model (pw.defaultReceiver)
%     lib         emitter-type library (pw.emitterLibrary)
%     emitters    instances: typeIdx, lla0, speed_mps, heading_deg,
%                 patrolLeg_m (moving emitters patrol back and forth),
%                 az0_deg (scan phase at t=0), revPeriods (per-revolution
%                 periods, s), esaT0 (ESA frame offset)
%     habs        instances: station [lat lon alt], lla (position at t=0)

if nargin < 1 || isempty(nHAB), nHAB = 4; end
if nargin < 2 || isempty(seed), seed = 1; end
rs = localRandStream(seed);

scn.origin = [36.0 -75.5 0];
scn.rx  = pw.defaultReceiver();
scn.lib = pw.emitterLibrary();
scn.seed = seed;

% ---- emitter instances -------------------------------------------------
%          id        lat     lon     alt   speed  heading  patrol leg (m)
inst = { 'FIX-S1',  35.75, -77.00,   40,     0,     0,    inf;
         'FIX-C1',  36.45, -76.60,   20,     0,     0,    inf;
         'MAR-X1',  35.60, -74.60,    0,     8,    45,   60e3;
         'MAR-S1',  36.40, -74.20,    0,    10,   200,   80e3;
         'AIR-X1',  37.10, -75.30, 8000,   220,   190,  150e3 };
ids = {scn.lib.id};
E = struct([]);
for i = 1:size(inst,1)
    e.typeIdx     = find(strcmp(ids, inst{i,1}));
    e.id          = inst{i,1};
    t             = scn.lib(e.typeIdx);
    e.lla0        = [inst{i,2} inst{i,3} inst{i,4} + t.antHeight_m];
    e.speed_mps   = inst{i,5};
    e.heading_deg = inst{i,6};
    e.patrolLeg_m = inst{i,7};         % back-and-forth leg (ships, aircraft CAP)
    e.az0_deg     = 360*rs.rand();
    % per-revolution periods over 2 h (rotating) with scan-rate jitter
    nRev = ceil(7200/max(t.scanPeriod_s,1e-3)) + 2;
    e.revPeriods  = t.scanPeriod_s*(1 + t.scanJitter*rs.randn(nRev,1));
    e.esaT0       = t.scanPeriod_s*rs.rand();
    E = [E e]; %#ok<AGROW>
end
scn.emitters = E;

% ---- HAB stations: ring around the AOI center, 20 km float ----------------
ringR = 45e3;                         % 45 km ring radius (~ 80-90 km baselines)
H = struct([]);
for i = 1:nHAB
    ang = 45 + (i-1)*360/nHAB;        % start NE, go clockwise
    xy  = ringR*[sind(ang) cosd(ang) 0];
    [~, lla] = pw.enu(scn.origin, xy, 'inverse');
    h.id = sprintf('HAB-%d', i);
    h.station = [lla(1) lla(2) 20e3];
    h.lla     = h.station;
    H = [H h]; %#ok<AGROW>
end
scn.habs = H;
end

function rs = localRandStream(seed)
% Small portable RNG wrapper (works in MATLAB and Octave).
state = seed;
rs.rand  = @() lcg();
rs.randn = @(varargin) boxmuller(varargin{:});
    function u = lcg(n)
        if nargin < 1, n = 1; end
        u = zeros(n,1);
        for j = 1:n
            state = mod(1103515245*state + 12345, 2^31);
            u(j) = (state + 0.5)/2^31;
        end
    end
    function z = boxmuller(n, m)
        if nargin < 1, n = 1; end
        if nargin < 2, m = 1; end
        N = n*m; u1 = lcg(N); u2 = lcg(N);
        z = reshape(sqrt(-2*log(u1)).*cos(2*pi*u2), n, m);
    end
end
