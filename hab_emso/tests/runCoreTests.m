function results = runCoreTests()
%RUNCORETESTS Regression tests for the pw library (MATLAB or GNU Octave).
%   results = runCoreTests()  prints PASS/FAIL per test and returns a struct
%   array. Run from the project root (the folder containing +pw), or after
%   running setupPaths.
%
%   These are plain-function tests so they also run in Octave. The
%   Agentic AI demo A1 asks an agent to write matlab.unittest tests; see
%   demos/agentic_ai/A1_agentic_toolkit/reference/tHabLinkBudget.m.

T = {};
T{end+1} = {'geometry: LLA<->ECEF round trip',          @tGeoRoundTrip};
T{end+1} = {'geometry: 20 km radio horizon ~583 km',     @tHorizon};
T{end+1} = {'link: FSPL 10 GHz @ 1 km = 112.4 dB',       @tFSPL};
T{end+1} = {'detection: Albersheim 13.1 dB & inverse',   @tAlbersheim};
T{end+1} = {'receiver: channel mapping and edges',       @tChannels};
T{end+1} = {'emitter: rotating scan completes 360 deg',  @tRotation};
T{end+1} = {'TDOA: constant PRI ambiguous, stagger not', @tTDOAAmbiguity};
T{end+1} = {'geolocation: noise-free scan-timing exact', @tScanExact};
T{end+1} = {'geolocation: TDOA error stats consistent',  @tTDOAConsistency};
T{end+1} = {'end-to-end: detect, classify, geolocate',   @tEndToEnd};
T{end+1} = {'signal level: filter bank + envelope PDW',  @tSignalLevel};
T{end+1} = {'HAB: altitude steering beats free drift',   @tStationKeeping};
T{end+1} = {'trade: evaluateDesign outputs sane',        @tDesign};

results = struct('name',{},'pass',{},'msg',{},'time',{});
for i = 1:numel(T)
    t0 = tic; msg = '';
    try
        msg = T{i}{2}();
        ok = true;
    catch err
        ok = false; msg = err.message;
    end
    results(end+1) = struct('name',T{i}{1},'pass',ok,'msg',msg,'time',toc(t0)); %#ok<AGROW>
    if ok, tag = 'PASS'; else, tag = 'FAIL'; end
    fprintf('[%s] %-45s %6.1fs  %s\n', tag, T{i}{1}, results(end).time, msg);
end
fprintf('\n%d of %d tests passed.\n', nnz([results.pass]), numel(results));
end

% ======================================================================
function msg = tGeoRoundTrip()
lla = [36 -75.5 20e3; -10 120 0; 60 10 8000];
back = pw.ecef2lla(pw.lla2ecef(lla));
e = max(abs(back(:) - lla(:)));
assert(e < 1e-6, 'round-trip error %g', e);
[~, lla2] = pw.enu(lla(1,:), [1000 2000 30], 'inverse');
xyz = pw.enu(lla(1,:), lla2);
assert(norm(xyz - [1000 2000 30]) < 1e-6);
msg = sprintf('max err %.1e', e);
end

function msg = tHorizon()
[~, ~, dh] = pw.isVisible([0 0 20e3], [0 0 0]);
assert(abs(dh/1e3 - 583) < 3, 'horizon %.1f km', dh/1e3);
msg = sprintf('%.0f km', dh/1e3);
end

function msg = tFSPL()
L = pw.fspl(10e9, 1e3);
assert(abs(L - 112.4) < 0.1, 'FSPL %.2f', L);
msg = sprintf('%.2f dB', L);
end

function msg = tAlbersheim()
s = pw.albersheim(0.9, 1e-6, 1);
assert(abs(s - 13.1) < 0.15, 'SNR %.2f', s);
pd = pw.pdFromSNR(s, 1e-6, 1);
assert(abs(pd - 0.9) < 1e-3, 'Pd %.4f', pd);
msg = sprintf('%.2f dB -> Pd %.3f', s, pd);
end

function msg = tChannels()
rx = pw.defaultReceiver(32);
assert(pw.channelOf(2.0e9, rx) == 1);
assert(pw.channelOf(2.49e9, rx) == 1);
assert(pw.channelOf(2.5e9, rx) == 2);
assert(pw.channelOf(17.99e9, rx) == 32);
assert(pw.channelOf(18.0e9, rx) == 0 && pw.channelOf(1.3e9, rx) == 0);
msg = sprintf('sens %.1f dBm/ch, %d ch', rx.sens_dBm(1), rx.nChannels);
end

function msg = tRotation()
scn = pw.defaultScenario();
em = scn.emitters(1); typ = scn.lib(em.typeIdx);
t = linspace(0, em.revPeriods(1)*0.999, 2000).';
az = pw.boresight(em, typ, t);
turned = sum(mod(diff(az)+180,360)-180);
assert(abs(abs(turned) - 360) < 1, 'turned %.1f', turned);
msg = sprintf('turned %.1f deg in %.2f s', turned, em.revPeriods(1));
end

function msg = tTDOAAmbiguity()
pw.setSeed(3);
tau = 123.4e-6; maxLag = 450e-6;
tc = (0:0.5e-3:0.4).';                                % constant PRI 0.5 ms
[~,~,~,ambC] = pw.measureTDOA(tc, tc + tau + 1e-9*randn(size(tc)), maxLag);
st = cumsum(repmat([0.95 1.02 0.98 1.05 1.00]'*1e-3, 80, 1));
[td,~,~,ambS] = pw.measureTDOA(st, st + tau + 1e-9*randn(size(st)), maxLag);
assert(ambC, 'constant PRI should be ambiguous');
% sparse sidelobe matches (E4 failure case): a single known PRI inside the
% lag window must be flagged, and a prediction must pick the right peak
sp = tc(rand(size(tc)) < 0.1);
[td2,~,~,amb2] = pw.measureTDOA(tc, sp + tau, maxLag, struct('pri', 0.5e-3, 'predicted', tau + 2e-6));
assert(amb2 && abs(td2 - tau) < 50e-9, 'sparse constant-PRI case not resolved');
assert(~ambS && abs(td - tau) < 5e-9, 'stagger TDOA %.3g', td);
msg = 'ok';
end

function msg = tScanExact()
scn = pw.defaultScenario();
habLLA = vertcat(scn.habs.lla);
truth = [36.2 -76.4 30];
T = 10; dir = 1;
az = zeros(1,4);
for j = 1:4, az(j) = pw.aer(truth, habLLA(j,:)); end
meas = struct('type',{},'i',{},'j',{},'value',{},'sigma',{},'period',{},'n',{},'group',{},'sigShared',{});
for j = 2:4
    dt = mod(dir*(az(j)-az(1)), 360)/360*T;
    meas(end+1) = struct('type','scan','i',1,'j',j,'value',dt,'sigma',1e-3, ...
        'period',T,'n',1,'group',1,'sigShared',0.5e-3); %#ok<AGROW>
end
sol = pw.geolocate(meas, habLLA, struct('alt',30));
e = pw.groundRange(sol.lla, truth);
assert(e < 1, 'error %.2f m', e);
assert(sol.rotDir == dir, 'rotation direction');
msg = sprintf('error %.3f m', e);
end

function msg = tTDOAConsistency()
% Monte Carlo: normalized squared error should average ~2 (2-D chi-square)
scn = pw.defaultScenario(); k = pw.const();
habLLA = vertcat(scn.habs.lla);
truth = [35.9 -75.9 30];
pE = pw.lla2ecef(truth); hE = pw.lla2ecef(habLLA);
R = sqrt(sum(bsxfun(@minus, hE, pE).^2, 2));
sig = 30e-9; pw.setSeed(11);
nT = 150; nees = zeros(nT,1);
for n = 1:nT
    b = sig*randn(4,1);
    meas = struct('type',{},'i',{},'j',{},'value',{},'sigma',{},'period',{},'n',{},'group',{},'sigShared',{});
    for j = 2:4
        v = (R(j)-R(1))/k.c + b(j) - b(1);
        meas(end+1) = struct('type','tdoa','i',1,'j',j,'value',v,'sigma',sqrt(2)*sig, ...
            'period',NaN,'n',100,'group',1,'sigShared',sig); %#ok<AGROW>
    end
    sol = pw.geolocate(meas, habLLA, struct('alt',30,'searchRadius',60e3,'gridStep',2e3));
    d = pw.enu(truth, sol.lla);
    e = d(1:2).';
    nees(n) = e.'*(sol.covENU(1:2,1:2)\e);
end
m = mean(nees);
assert(m > 1.5 && m < 2.6, 'mean NEES %.2f (expect ~2)', m);
msg = sprintf('mean NEES %.2f (ideal 2.0)', m);
end

function msg = tEndToEnd()
scn = pw.defaultScenario(); rx = scn.rx;
pdw = pw.generatePDWs(scn, 0, 32);
nH = numel(scn.habs); habLLA = vertcat(scn.habs.lla);
C = cell(1,nH);
for h = 1:nH, C{h} = pw.deinterleave(pdw, h, struct('rx',rx)); end
G = pw.associateClusters(C);
found = false(1,numel(scn.emitters)); located = found; errs = nan(1,numel(found));
for g = 1:numel(G)
    m = G(g).members;
    tr = arrayfun(@(r) C{m(r,1)}(m(r,2)).truth, 1:size(m,1));
    ie = mode(tr); if ie == 0, continue; end
    em = scn.emitters(ie); typ = scn.lib(em.typeIdx);
    id = pw.classifyEmitter(C{m(1,1)}(m(1,2)), scn.lib, rx);
    assert(strcmp(id, em.id), 'misclassified %s as %s', em.id, id);
    found(ie) = true;
    alt = em.lla0(3); if strcmp(typ.class,'airborne'), alt = NaN; end
    sol = pw.locateGroup(pdw, G(g), C, habLLA, rx, alt);
    if ~isempty(sol)
        errs(ie) = pw.groundRange(sol.lla, pw.emitterPosition(em, 16));
        located(ie) = errs(ie) < 1500;
    end
end
assert(all(found), 'not all emitters detected/classified');
isRot = arrayfun(@(e) strcmp(scn.lib(e.typeIdx).scanType,'rotating'), scn.emitters);
assert(all(located(isRot)), 'rotating emitter not located within 1.5 km');
assert(~any(located(~isRot)), 'ESA emitter unexpectedly located');
msg = sprintf('5/5 classified; rotating errors (m): %s', mat2str(round(errs(isRot))));
end

function msg = tSignalLevel()
rx = pw.defaultReceiver(32);
fs = 40e9; T = 6e-6; t = (0:1/fs:T-1/fs).';
f0 = 9.41e9; PW = 0.5e-6; t0 = 2e-6;
sigma = 1e-3; A = sigma*sqrt(2)*10^(20/20)*sqrt(2*rx.B(1)/fs);   % ~20 dB in-channel SNR
x = sigma*randn(size(t)) + A*cos(2*pi*f0*t).*(t >= t0 & t < t0 + PW);
c = pw.channelOf(f0, rx);
[v, tv] = pw.rfFrontEnd(x, fs, rx, [c 5]);
noise = median(v(:,1));
P = pw.extractPDW(v(:,1), tv, 8*noise);
[~, ib] = max(P.peak);
assert(abs(P.toa(ib) - t0) < 20e-9, 'TOA error %.1f ns', (P.toa(ib)-t0)*1e9);
assert(abs(P.pw(ib) - PW)/PW < 0.1, 'PW error');
assert(max(v(:,2)) < 8*median(v(:,2)), 'leak into far channel');
msg = sprintf('TOA err %.1f ns, PW %.3f us', (P.toa(ib)-t0)*1e9, P.pw(ib)*1e6);
end

function msg = tStationKeeping()
st = [36.3 -75.1 19e3];
a = pw.simulateHAB(st, 48*3600, struct('altBand',[15e3 23e3]));
b = pw.simulateHAB(st, 48*3600, struct('steer',false));
assert(a.fracOnStation > 0.8, 'steered %.2f', a.fracOnStation);
assert(b.fracOnStation < 0.3, 'free %.2f', b.fracOnStation);
msg = sprintf('within 50 km: steered %.0f%%, free drift %.0f%%', 100*a.fracOnStation, 100*b.fracOnStation);
end

function msg = tDesign()
M = pw.evaluateDesign(struct());
assert(M.perClass(1).coverGeo > 0.9, 'fixed-site coverage');
assert(M.perClass(3).coverGeo < 0.05, 'airborne without DF should be ~0');
M2 = pw.evaluateDesign(struct('dfOption',1,'nChannels',16,'nHAB',6,'ringRadius_km',80));
assert(M2.perClass(3).coverGeo > M.perClass(3).coverGeo, 'DF should add airborne coverage');
assert(M2.cost_USD > M.cost_USD);
msg = sprintf('baseline $%.2fM geo %.2f; DF/6-HAB $%.2fM geo %.2f', M.cost_USD/1e6, M.geoCoverage, M2.cost_USD/1e6, M2.geoCoverage);
end
