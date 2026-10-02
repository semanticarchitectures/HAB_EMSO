function M = evaluateDesign(design, opts)
%PW.EVALUATEDESIGN Cost and performance of a HAB-constellation design.
%   M = pw.evaluateDesign(design)
%   M = pw.evaluateDesign(design, opts)
%
%   design fields (defaults in brackets)
%     nHAB           number of balloons                         [4]
%     ringRadius_km  station ring radius around the AOI center  [45]
%     floatAlt_km    nominal float altitude                     [20]
%     nChannels      filter-bank channels across 2-18 GHz       [32]
%     sigmaSync_ns   inter-HAB clock error, 1-sigma             [30]
%     altBandHalf_km altitude-control authority: the balloon can use
%                    floatAlt +- this value. Station keeping needs winds from
%                    (nearly) all directions inside the band.       [4]
%     dfOption       0 = filter bank only; 1 = add amplitude-comparison
%                    direction finding (4 squinted antennas, each with its
%                    own filter bank -> ~4x channel hardware)   [0]
%                    Bearings (sigma ~6 deg) let >= 2 HABs triangulate an
%                    electronically scanned emitter from mainbeam intercepts
%                    at different times (slow-moving relative to a frame).
%   opts
%     aoiHalfWidth_km  AOI half-width (square box)               [200]
%     gridStep_km      evaluation grid spacing                   [20]
%     simHours         station-keeping simulation length         [48]
%     campaignDays     campaign length for cost                  [90]
%     stationFrac      precomputed station-keeping fraction (skips the
%                      balloon simulation; use when sweeping many designs
%                      that share floatAlt_km / altBandHalf_km)
%     cepGoal_m        CEP50 goal per class [fixed marine airborne]
%                      default [1000 1000 25000]. The airborne goal is a
%                      CUEING goal (hand-off to an onboard or surface sensor
%                      that searches a ~25 km basket), not a targeting goal.
%
%   M fields
%     perClass(c): class, coverDetect, coverGeo (fraction of AOI with
%       CEP50 below the class goal), medianCEP_m, cepMap
%     geoCoverage     mean coverGeo over the three emitter classes
%     medianCEP_m     median CEP over all geolocatable points
%     fracOnStation   single-HAB station-keeping fraction
%     pAtLeast3       P(>= 3 HABs on station), binomial
%     effGeoCoverage  geoCoverage * pAtLeast3
%     cost_USD        campaign cost (notional)
%     payloadMass_kg, payloadPower_W, feasible (SWaP limits met)
%
%   ALL cost, SWaP and bus numbers are NOTIONAL placeholders.
if nargin < 2, opts = struct(); end
dflt = struct('nHAB',4,'ringRadius_km',45,'floatAlt_km',20,'nChannels',32,'sigmaSync_ns',30,'dfOption',0,'altBandHalf_km',4);
f = fieldnames(dflt);
for i = 1:numel(f), if ~isfield(design,f{i}), design.(f{i}) = dflt.(f{i}); end, end
od = struct('aoiHalfWidth_km',200,'gridStep_km',20,'simHours',48,'campaignDays',90, ...
            'cepGoal_m',[1000 1000 25000]);
f = fieldnames(od);
for i = 1:numel(f), if ~isfield(opts,f{i}), opts.(f{i}) = od.(f{i}); end, end

nHAB = max(3, round(design.nHAB));
rx = pw.defaultReceiver(round(design.nChannels));
rx.sigmaSync_s = design.sigmaSync_ns*1e-9;
lib = pw.emitterLibrary();
origin = [36.0 -75.5 0];

% HAB stations on a ring
habLLA = zeros(nHAB,3);
for i = 1:nHAB
    ang = 45 + (i-1)*360/nHAB;
    [~, l] = pw.enu(origin, design.ringRadius_km*1e3*[sind(ang) cosd(ang) 0], 'inverse');
    habLLA(i,:) = [l(1:2) design.floatAlt_km*1e3];
end

% AOI grid
g = (-opts.aoiHalfWidth_km:opts.gridStep_km:opts.aoiHalfWidth_km)*1e3;
[X, Y] = meshgrid(g, g);
[~, P0] = pw.enu(origin, [X(:) Y(:) zeros(numel(X),1)], 'inverse');
N = size(P0,1);

classes = {'fixed','marine','airborne'};
repType = {'FIX-S1','MAR-X1','AIR-X1'};      % representative (hardest common) type per class
emAlt   = [30 25 8000];
allCEP = [];
for c = 1:3
    typ = lib(strcmp({lib.id}, repType{c}));
    P = P0; P(:,3) = emAlt(c);
    [mainOK, sideOK] = pw.usableHABs(typ, P, habLLA, rx);
    prm.sigmaTDOA_s = sqrt(2)*rx.sigmaSync_s;
    prm.sigmaAz_deg = 0.08;
    cepT = inf(N,1); cepS = inf(N,1);
    prm.usable = sideOK;
    if any(sum(sideOK,2) >= 3), cepT = pw.geolocationCRLB(habLLA, P, 'tdoa', prm); end
    if strcmp(typ.scanType,'rotating')
        prm.usable = mainOK;
        if any(sum(mainOK,2) >= 3), cepS = pw.geolocationCRLB(habLLA, P, 'scan', prm); end
    end
    cepA = inf(N,1);
    if design.dfOption >= 0.5
        prm.usable = mainOK; prm.sigmaAOA_deg = 6;
        if any(sum(mainOK,2) >= 2), cepA = pw.geolocationCRLB(habLLA, P, 'aoa', prm); end
    end
    cep = 1./sqrt(1./cepT.^2 + 1./cepS.^2 + 1./cepA.^2);
    M.perClass(c).class = classes{c};
    M.perClass(c).coverDetect = mean(any(mainOK,2));
    M.perClass(c).coverGeo = mean(cep < opts.cepGoal_m(c));
    ok = isfinite(cep);
    if any(ok), M.perClass(c).medianCEP_m = median(cep(ok)); else, M.perClass(c).medianCEP_m = inf; end
    M.perClass(c).cepMap = reshape(cep, size(X));
    allCEP = [allCEP; cep(ok)]; %#ok<AGROW>
end
M.gridX_km = X/1e3; M.gridY_km = Y/1e3; M.habLLA = habLLA; M.origin = origin;
M.geoCoverage = mean([M.perClass.coverGeo]);
if isempty(allCEP), M.medianCEP_m = inf; else, M.medianCEP_m = median(allCEP); end

% station keeping (one representative balloon; altitude band = float +- 3 km)
if isfield(opts,'stationFrac') && ~isempty(opts.stationFrac)
    p = opts.stationFrac;
else
    tr = pw.simulateHAB(habLLA(1,:), opts.simHours*3600, ...
         struct('altBand', design.floatAlt_km*1e3 + design.altBandHalf_km*[-1e3 1e3], 'dt', 60));
    p = tr.fracOnStation;
end
M.fracOnStation = p;
pk = 0;
for kk = 3:nHAB, pk = pk + nchoosek(nHAB,kk)*p^kk*(1-p)^(nHAB-kk); end
M.pAtLeast3 = pk;
M.effGeoCoverage = M.geoCoverage*pk;

% SWaP-C (notional)
syncCost = interp1([5 10 30 100], [30e3 15e3 0 -3e3], min(max(design.sigmaSync_ns,5),100));
syncMass = interp1([5 10 30 100], [0.6 0.3 0 0], min(max(design.sigmaSync_ns,5),100));
busCost   = 120e3 + 30e3*max(design.altBandHalf_km - 3, 0);  % envelope, altitude
                                    % control (larger band = more ballonet/lift), solar, datalink
launchOps = 30e3;                   % per flight
flightDays = 100;                   % notional endurance
flights = ceil(opts.campaignDays/flightDays);
df = design.dfOption >= 0.5;
chanMass = rx.mass_kg - 0.8; chanPow = rx.power_W - 4.0; chanCost = rx.unitCost_USD - 15e3;
M.payloadMass_kg = rx.mass_kg + syncMass + df*(3*chanMass + 0.4);     % + antennas
M.payloadPower_W = rx.power_W + 2*(design.sigmaSync_ns < 20) + df*3*chanPow;
payloadCost = rx.unitCost_USD + syncCost + df*(3*chanCost + 8e3);
M.cost_USD = nHAB*(payloadCost + flights*(busCost + launchOps));
M.feasible = M.payloadMass_kg <= 4.0 && M.payloadPower_W <= 25;
M.design = design; M.rx = rx;
end
