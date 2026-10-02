%% E1 - SENSE: Signal-Level Model of the Filter-Bank Detector
% Seminar: End-to-End EMSO Modeling in MATLAB (RF intercept)
% Companion to the MathWorks example "Signal Parameter Estimations in a
% Radar Warning Receiver" -- that RWR digitizes, channelizes and runs
% MUSIC/Wigner-Ville. The notional Philowave-class payload takes the
% opposite, minimum-SWaP path:
%     antenna -> narrowband filter bank -> envelope detector -> threshold
% and reports only pulse descriptor words (PDWs): channel, TOA, PW, amp.
%
% This demo pushes a 30-microsecond RF snapshot (sampled at 40 GS/s,
% 2-18 GHz) containing several emitters through the 32-channel model
% and extracts PDWs. It also shows two real-world artifacts:
%   * a strong pulse right at a channel edge (3.005 GHz, edge at 3.0 GHz)
%     appears in BOTH channels (filter skirts) -> duplicate PDWs with the
%     same TOA that the deinterleaver must merge
%   * a continuous communications signal raises one channel's floor
%     (no pulses -> no PDWs, but a measurable noise-floor rise)
% NOTIONAL parameters throughout.

setupPaths;
pw.setSeed(42);
rx = pw.defaultReceiver();

%% 1. Build the RF snapshot
fs = 40e9; T = 30e-6; t = (0:1/fs:T-1/fs).'; N = numel(t);
sigma = 1;                                   % noise std (V), white to fs/2
Pn_ch = sigma^2*2*rx.B(1)/fs;                % noise power in one 500 MHz channel
amp = @(snr_dB) sqrt(2*Pn_ch*10^(snr_dB/10));
x = sigma*randn(N,1);
% emitter            f (GHz)  PW (us) t0 (us)  in-channel SNR (dB)
E = { 'FIX-S1 (S-band)',  2.95,   2.0,    3.0,   30;
      'S-band at 3.005',  3.005,  1.0,   12.0,   35;
      'FIX-C1 (C-band)',  5.60,   5.0,    6.0,   22;
      'MAR-X1 (X-band)',  9.41,   0.5,   20.0,   18;
      'AIR-X1 hop 1',     9.70,   3.0,    1.0,   16;
      'AIR-X1 hop 2',    10.10,   3.0,   24.0,   16 };
truth = struct('name',{},'ch',{},'t0',{},'pw',{});
for i = 1:size(E,1)
    f = E{i,2}*1e9; PW = E{i,3}*1e-6; t0 = E{i,4}*1e-6;
    m = t >= t0 & t < t0 + PW;
    x(m) = x(m) + amp(E{i,5})*cos(2*pi*f*t(m) + 2*pi*rand);
    truth(end+1) = struct('name',E{i,1},'ch',pw.channelOf(f,rx),'t0',t0,'pw',PW); %#ok<SAGROW>
end
% continuous QPSK-like communications signal at 7.25 GHz, 40 MHz wide, 3 dB above floor
fc = 7.25e9; sym = 40e6; ns = ceil(T*sym);
bits = exp(1i*pi/2*floor(4*rand(ns,1)));
bb = bits(min(floor(t*sym)+1, ns));
x = x + sqrt(2*Pn_ch*10^(3/10))*real(bb.*exp(1i*2*pi*fc*t));
commsCh = pw.channelOf(fc, rx);

%% 2. Filter bank + envelope detectors (all 32 channels)
[video, tv] = pw.rfFrontEnd(x, fs, rx);
noiseRef = median(video(tv < 0.8e-6 | tv > 29e-6, :), 1);   % per-channel floor
Vn = bsxfun(@rdivide, video, median(noiseRef));

figure('Name','E1 filter-bank video');
imagesc(tv*1e6, 1:rx.nChannels, 10*log10(Vn.')); axis xy; colorbar
caxis([-5 35]); xlabel('time (\mus)'); ylabel('channel');
yt = 1:4:rx.nChannels;
set(gca, 'YTick', yt, 'YTickLabel', arrayfun(@(c) sprintf('%d: %.1f GHz', c, rx.fCenter(c)/1e9), yt, 'UniformOutput', false));
title('Detector video, dB over noise: pulses, an edge spill, and a comms floor rise');

%% 3. Threshold and PDW extraction per channel
% Threshold 10 dB over each channel's own noise floor -- note that the
% comms channel's floor is higher, so its threshold rises with it (the
% same idea as CFAR in the Radar seminar demo R4).
floorCh = median(video, 1);
P = struct('ch',{},'toa',{},'pw',{},'amp_dB',{});
for c = 1:rx.nChannels
    q = pw.extractPDW(video(:,c), tv, 10*floorCh(c));
    for k = 1:numel(q.toa)
        if q.pw(k) < 50e-9, continue; end               % reject noise spikes
        P(end+1) = struct('ch',c,'toa',q.toa(k),'pw',q.pw(k), ...
            'amp_dB',10*log10(q.level(k)/floorCh(c))); %#ok<SAGROW>
    end
end
fprintf('\n%-4s %-10s %9s %8s %9s   %s\n','#','channel','TOA (us)','PW (us)','dB>floor','best truth match');
for k = 1:numel(P)
    [dm, j] = min(abs([truth.t0] - P(k).toa));
    tag = truth(j).name;
    if truth(j).ch ~= P(k).ch, tag = [tag ' <-- same pulse, ADJACENT channel (edge straddle)']; end
    if dm > 0.2e-6, tag = '(no truth match)'; end
    fprintf('%-4d %2d %6.2fGHz %9.3f %8.3f %9.1f   %s\n', k, P(k).ch, rx.fCenter(P(k).ch)/1e9, ...
        P(k).toa*1e6, P(k).pw*1e6, P(k).amp_dB, tag);
end
fprintf('\nComms channel %d floor is %.1f dB above the median channel floor (no PDWs).\n', ...
    commsCh, 10*log10(floorCh(commsCh)/median(floorCh)));

%% 4. What survived, what did not
% Survived: channel (~500 MHz frequency bins), TOA to a few ns, PW, amplitude.
% Lost:     phase, fine frequency, intrapulse modulation, AOA.
% Consequences for the rest of the EMSO chain:
%  * identification must rely on channel + PW + PRI + scan (E2)
%  * location must come from multiple balloons (TDOA, scan timing) (E3)
%  * duplicate PDWs from edge spill share a TOA -> merge by coincidence
%  * continuous emitters show up as floor rises, not PDWs -> separate
%    energy-detection logic (see E5 discussion)
