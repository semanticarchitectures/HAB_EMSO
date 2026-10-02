%% R4 - CFAR Detection on the Filter-Bank Detector Output
% Seminar: Introduction to Radar Signal Processing with MATLAB and Simulink
% Topics:  CFAR detection, clutter/interference, detection thresholds
%
% Radars use constant false alarm rate (CFAR) thresholds so the false
% alarm rate stays fixed when the clutter or noise level changes. The same
% problem hits every channel of the balloon's filter-bank detector: a
% jammer, a co-channel communications signal, or spill from a very strong
% nearby emitter raises the channel's noise floor. A fixed threshold then
% floods the downstream deinterleaver with false pulses.
%
% This demo digitizes one 500 MHz channel's square-law output (2 ns
% samples, 1 ms) with two pulsed emitters and a 10 dB noise-floor step at
% 0.5 ms, and compares a fixed threshold with cell-averaging CFAR.
% (For the radar's own data-cube CFAR and clutter filtering, pair this with
% the seminar's radar_datacube_clutter_cfar_01.m example.)  NOTIONAL values.

setupPaths;
pw.setSeed(21);

%% 1. One channel, complex baseband, 500 MS/s (one sample per 1/B)
fs = 500e6; T = 1e-3; N = round(T*fs); t = (0:N-1).'/fs;
floorStep_dB = 10; tStep = 0.5e-3;
nPow = ones(N,1); nPow(t >= tStep) = 10^(floorStep_dB/10);
w = sqrt(nPow/2).*(randn(N,1) + 1i*randn(N,1));

% emitter A: 0.5 us pulses, 50 us PRI, 13 dB SNR (weak, e.g. far marine radar)
% emitter B: 2 us pulses, 137 us PRI, 22 dB SNR (strong, e.g. fixed site)
s = zeros(N,1);
s = s + pulses(t, 0.5e-6, 50e-6, 3e-6, 10^(13/20));
s = s + pulses(t, 2.0e-6, 137e-6, 11e-6, 10^(22/20));
x = abs(s + w).^2;                           % square-law detector output

%% 2. Fixed threshold (set for Pfa at the ORIGINAL noise level)
Pfa = 1e-6;
thrFixed = -log(Pfa)*1;                      % exponential noise, unit mean
detFixed = x > thrFixed;

%% 3. Cell-averaging CFAR (guard cells span the longest pulse)
nTrain = 400; nGuard = 1100;                 % per side: 0.8 us / 2.2 us
if pw.hasToolbox('phased')
    cfar = phased.CFARDetector('Method','CA', 'NumTrainingCells', 2*nTrain, ...
        'NumGuardCells', 2*nGuard, 'ProbabilityFalseAlarm', Pfa, ...
        'ThresholdOutputPort', true);
    cut = (nTrain+nGuard+1 : N-nTrain-nGuard).';
    [d, th] = cfar(x, cut);
    detCFAR = false(N,1); detCFAR(cut) = d;
    thrCFAR = inf(N,1); thrCFAR(cut) = th;
else
    [detCFAR, thrCFAR] = pw.caCFAR(x, nTrain, nGuard, Pfa);
end

%% 4. Form PDWs (merge threshold crossings closer than 20 ns into one pulse)
P_fixed = formPulses(detFixed, t, 10);
P_cfar  = formPulses(detCFAR,  t, 10);
truthA = 3e-6:50e-6:T; truthB = 11e-6:137e-6:T;
truth = sort([truthA truthB]);
score = @(P) matchTruth(P, truth, 0.3e-6);
[hitF, faF] = score(P_fixed); [hitC, faC] = score(P_cfar);
pre = t < tStep;
fprintf('%-18s %8s %8s %14s %14s\n','threshold','pulses','hits','false (0-0.5ms)','false (0.5-1ms)');
fprintf('%-18s %8d %8d %14d %14d\n','fixed', numel(P_fixed), hitF, ...
    nnz(faF & P_fixed < tStep), nnz(faF & P_fixed >= tStep));
fprintf('%-18s %8d %8d %14d %14d\n','CA-CFAR', numel(P_cfar), hitC, ...
    nnz(faC & P_cfar < tStep), nnz(faC & P_cfar >= tStep));
fprintf('true pulses: %d (A: %d weak, B: %d strong)\n', numel(truth), numel(truthA), numel(truthB));

%% 5. Plot
figure('Name','R4 CFAR');
dec = 4;  % plot every 4th sample for speed
plot(t(1:dec:end)*1e3, 10*log10(x(1:dec:end)), 'Color', [0.6 0.6 0.6]); hold on
plot(t([1 end])*1e3, 10*log10(thrFixed)*[1 1], 'r', 'LineWidth', 1.2);
plot(t(1:dec:end)*1e3, 10*log10(thrCFAR(1:dec:end)), 'b', 'LineWidth', 1.2);
grid on; ylim([-20 35]); xlabel('time (ms)'); ylabel('dB (re: initial noise)');
legend('detector output','fixed threshold','CA-CFAR threshold','Location','northwest');
title('Noise floor steps up 10 dB at 0.5 ms: fixed threshold floods, CFAR adapts');

%% 6. Take-aways
% * CFAR holds the false-alarm rate when the floor rises, protecting the
%   deinterleaver (every false PDW costs processing and link bandwidth).
% * The weak emitter is lost after the step -- CFAR cannot restore SNR.
%   The raised channel floor is itself a detection: its level and timing
%   are information about a jammer/communications emitter (see EMSO E5).
% * Guard cells must span the longest pulse, or a long pulse raises its
%   own threshold (self-masking).

% Helper functions pulses.m, formPulses.m and matchTruth.m are in ./private
