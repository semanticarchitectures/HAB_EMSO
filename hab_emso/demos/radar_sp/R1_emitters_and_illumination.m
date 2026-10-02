%% R1 - The Radars the Balloons Listen To: Waveforms, Scan and Illumination
% Seminar: Introduction to Radar Signal Processing with MATLAB and Simulink
% Topics:  radar signal processing workflow, radar waveform, antenna scan
%
% A high-altitude balloon (HAB) carrying a Philowave-class filter-bank
% detector never sees a radar's data cube. It sees only what the radar
% radiates toward it: a pulse train whose amplitude is modulated by the
% radar's antenna as it scans. This demo builds the three notional emitter
% classes used throughout the seminar series and shows what one balloon
% receives from each:
%   * FIXED site  - mechanically rotating fan beam (S-band surveillance)
%   * MARINE      - mechanically rotating fan beam (X-band navigation)
%   * AIRBORNE    - electronically scanned (AESA) raster, frequency agile
%
% ALL PARAMETERS ARE NOTIONAL (see pw.emitterLibrary, pw.defaultReceiver).

setupPaths;
scn = pw.defaultScenario();
lib = scn.lib; rx = scn.rx;

%% 1. The notional emitter library
fprintf('\n%-7s %-9s %8s %9s %7s %8s %9s %9s  %s\n', 'ID','class','f (GHz)', ...
    'Ppk (kW)','G(dBi)','PW (us)','PRI (us)','scan (s)','description');
for i = 1:numel(lib)
    L = lib(i);
    fprintf('%-7s %-9s %8.2f %9.0f %7.0f %8.1f %9.0f %9.3f  %s\n', L.id, L.class, ...
        L.fc/1e9, L.Ppeak_W/1e3, L.G_dBi, L.PW_s*1e6, mean(L.PRI_s)*1e6, ...
        L.scanPeriod_s, L.description);
end

%% 2. Pulse trains (a few PRIs) -- staggered, constant and per-dwell PRIs
figure('Name','R1 pulse trains');
ids = {'FIX-S1','MAR-X1','AIR-X1'};
for q = 1:3
    L = lib(strcmp({lib.id}, ids{q}));
    pri = L.PRI_s(:);
    if strcmp(L.scanType,'esa'), pri = repmat(pri(1), 8, 1);
    else, pri = repmat(pri, ceil(8/numel(pri)), 1); pri = pri(1:8); end
    tp = [0; cumsum(pri)];
    t = linspace(0, tp(end), 20000);
    x = zeros(size(t));
    for k = 1:numel(tp)-1, x(t >= tp(k) & t < tp(k) + L.PW_s) = 1; end
    subplot(3,1,q); plot(t*1e3, x, 'LineWidth', 1); ylim([-0.1 1.2]);
    title(sprintf('%s  PW %.1f us, PRI(s) %s us', L.id, L.PW_s*1e6, ...
        mat2str(round(L.PRI_s*1e6)))); ylabel('envelope');
end
xlabel('time (ms)');

%% 3. Antenna patterns: rotating fan beam vs low-sidelobe AESA
% Simple analytic patterns (Gaussian mainbeam + sidelobe floor), see
% pw.txGain. With Phased Array System Toolbox the same beamwidths are
% reproduced with a uniform linear array for comparison.
az = linspace(-30, 30, 2001).';
figure('Name','R1 antenna patterns');
for q = 1:3
    L = lib(strcmp({lib.id}, ids{q}));
    if strcmp(L.scanType,'esa')
        G = pw.txGain(L, zeros(size(az)), zeros(size(az)), az, zeros(size(az)), zeros(size(az)));
    else
        G = pw.txGain(L, zeros(size(az)), [], az, 5*ones(size(az)));
    end
    plot(az, G - L.G_dBi, 'LineWidth', 1.2); hold on
end
if pw.hasToolbox('phased')
    % 30-element ULA with Taylor taper ~ AESA-like low sidelobes at 9.8 GHz
    c = physconst('LightSpeed'); f = 9.8e9; lam = c/f;
    arr = phased.ULA('NumElements', 30, 'ElementSpacing', lam/2, ...
        'Taper', taylorwin(30, 5, -35));
    pat = pattern(arr, f, az.', 0, 'Type', 'powerdb', 'Normalize', true);
    plot(az, pat, 'k:', 'LineWidth', 1);
    legend([ids, {'30-el ULA, Taylor -35 dB (Phased Array)'}], 'Location', 'south');
else
    legend(ids, 'Location', 'south');
end
grid on; ylim([-50 3]); xlabel('azimuth off boresight (deg)');
ylabel('relative gain (dB)'); title('Transmit antenna patterns (notional)');

%% 4. What one balloon receives: amplitude vs time over several scans
% Measurement-level simulation of every pulse (pw.generatePDWs), 32 s
hab = 1;
pdw = pw.generatePDWs(scn, 0, 32, struct('habs', hab, 'falseAlarms', false));
figure('Name','R1 illumination');
names = {scn.emitters.id};
for ie = 1:numel(scn.emitters)
    m = pdw.emitter == ie;
    subplot(numel(scn.emitters),1,ie);
    if any(m)
        plot(pdw.toa(m), pdw.amp(m), '.', 'MarkerSize', 3);
    end
    ylabel('dBm'); title(sprintf('%s at %s', names{ie}, scn.habs(hab).id));
    ylim([rx.sens_dBm(1)-3 -15]); grid on
end
xlabel('time (s)');
% Rotating radars: a narrow mainbeam "flash" once per revolution on top of
% a sidelobe floor (strong fixed sites are heard on EVERY pulse, even in
% sidelobes). The AESA: short flat-topped dwells whenever the raster passes
% the balloon, nothing in between -- its -35 dB sidelobes are below the
% detector's sensitivity at these ranges.

%% 5. What the balloon can infer from those pulses alone
% Deinterleave by channel and pulse width, estimate PRIs, and classify the
% scan from the illumination pattern (pw.deinterleave). Frequency agility
% across filter channels marks the AESA as electronically scanned.
cl = pw.deinterleave(pdw, hab, struct('rx', rx));
fprintf('\n%-8s %-10s %8s %-28s %-10s %9s\n','truth','channels','PW (us)','PRIs (us)','scan','period(s)');
for q = 1:numel(cl)
    fprintf('%-8s %-10s %8.2f %-28s %-10s %9.3f\n', names{cl(q).truth}, mat2str(cl(q).channels), ...
        cl(q).pw*1e6, mat2str(round(cl(q).priSet*1e6)), cl(q).scan.scanType, cl(q).scan.period);
end
