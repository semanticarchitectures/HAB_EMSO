%% E2 - UNDERSTAND: Deinterleave, PRI Analysis, Scan Analysis, Identify
% Seminar: End-to-End EMSO Modeling in MATLAB (emitter features & ID)
%
% Every balloon produces an interleaved PDW stream from all emitters in
% view. With only channel / TOA / PW / amplitude available, the balloon
% (or the ground processor) must:
%   1. deinterleave into per-emitter pulse trains  (channel + PW clusters)
%   2. estimate the PRI structure                   (difference histogram)
%   3. estimate the scan: rotating vs electronic, period, beamwidth
%   4. identify against a parametric library        (pw.classifyEmitter)
%   5. associate the same emitter across balloons   (pw.associateClusters)
% Measurement-level simulation: every pulse of 5 notional emitters to 4
% altitude-steered HABs for 32 s (pw.generatePDWs). NOTIONAL parameters.

setupPaths;
scn = pw.defaultScenario();
rx = scn.rx; nH = numel(scn.habs); names = {scn.emitters.id};

%% 1. Simulate the PDW streams (all pulses, all balloons, 32 s)
tic; pdw = pw.generatePDWs(scn, 0, 32); tSim = toc;
fprintf('%d PDWs at %d balloons in %.1f s of simulated time (%.1f s to simulate)\n', ...
    numel(pdw.toa), nH, 32, tSim);
for h = 1:nH
    m = pdw.hab == h;
    fprintf('  %s: %7d PDWs, %4d false alarms\n', scn.habs(h).id, nnz(m), nnz(m & pdw.emitter == 0));
end

%% 2. Deinterleave each balloon's stream
C = cell(1,nH);
for h = 1:nH
    C{h} = pw.deinterleave(pdw, h, struct('rx', rx));
end
h = 1;
fprintf('\n%s clusters:\n%-3s %-10s %8s %7s %-30s %-9s %8s %7s\n', scn.habs(h).id, '#', ...
    'channels', 'PW (us)', 'pulses', 'PRIs (us)', 'scan', 'T (s)', 'purity');
for q = 1:numel(C{h})
    c = C{h}(q);
    fprintf('%-3d %-10s %8.2f %7d %-30s %-9s %8.3f %6.0f%%\n', q, mat2str(c.channels), c.pw*1e6, ...
        c.n, mat2str(round(c.priSet*1e6)), c.scan.scanType, c.scan.period, 100*c.purity);
end

%% 3. PRI difference histograms (HAB-1): stagger, constant, per-dwell PRIs
figure('Name','E2 PRI histograms');
for q = 1:numel(C{h})
    c = C{h}(q);
    a = pdw.amp(c.idx); strong = a >= max(a) - 15;
    d = diff(sort(pdw.toa(c.idx(strong)))); d = d(d < 3e-3);
    subplot(numel(C{h}),1,q);
    edges = 0:1e-6:2.2e-3;
    if max(d) < 200e-6, edges = 0:0.5e-6:120e-6; end
    hc = histc(d, edges); bar(edges*1e6, hc, 'histc');
    title(sprintf('cluster %d (truth %s): consecutive TOA differences', q, names{c.truth}));
    ylabel('count');
end
xlabel('\DeltaTOA (\mus)');

%% 4. Scan analysis: mainbeam bursts and their parabolic fits (HAB-1)
figure('Name','E2 scan analysis');
for q = 1:numel(C{h})
    c = C{h}(q);
    subplot(numel(C{h}),1,q);
    plot(pdw.toa(c.idx), pdw.amp(c.idx), '.', 'MarkerSize', 3); hold on
    sc = c.scan;
    if ~isempty(sc.tCenter)
        plot(sc.tCenter, sc.peak_dBm, 'rv', 'MarkerFaceColor', 'r');
    end
    title(sprintf('truth %s -> scan %s, period %.3f s, beamwidth %.2f deg', names{c.truth}, ...
        sc.scanType, sc.period, sc.beamwidth_deg));
    ylabel('dBm'); grid on
end
xlabel('time (s)');

%% 5. Identify and associate across balloons
G = pw.associateClusters(C);
fprintf('\n%-3s %-14s %-7s %-10s %-9s %8s  %s\n','grp','HABs','truth','ID','scan','score','runner-up');
for g = 1:numel(G)
    m = G(g).members;
    c1 = C{m(1,1)}(m(1,2));
    [id, sc, ranked] = pw.classifyEmitter(c1, scn.lib, rx);
    tr = names{c1.truth};
    fprintf('%-3d %-14s %-7s %-10s %-9s %8.2f  %s (%.2f)\n', g, mat2str(m(:,1).'), tr, id, ...
        G(g).scanType, sc, ranked.id{2}, ranked.score(2));
end

%% 6. Take-aways
% * Channel + PW separates these five emitters cleanly; in a denser
%   environment, emitters sharing a 500 MHz channel and similar PW must be
%   split by PRI and scan -- report confidence and runner-up, not just ID.
% * The frequency-agile AESA is re-assembled from three channels by its
%   PW/PRI signature and flagged as electronically scanned ('raster').
% * Scan period and apparent beamwidth come for free from the amplitude
%   history -- and the mainbeam burst TIMES are the raw material for
%   scan-timing geolocation in E3.
