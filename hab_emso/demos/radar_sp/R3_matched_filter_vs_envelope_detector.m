%% R3 - Pulse Compression and Matched Filtering vs. the Envelope Detector
% Seminar: Introduction to Radar Signal Processing with MATLAB and Simulink
% Topics:  pulse compression, matched filter, range estimation
%
% A radar knows its own waveform, so it matched-filters: SNR gain = time-
% bandwidth product, and range resolution = c/(2B). An intercept receiver
% does NOT know the waveform in advance. The Philowave-class architecture
% therefore uses a wide channel filter + square-law (envelope) detector:
% no phase, no correlation gain, but microsecond response across octaves
% at very low SWaP. This demo quantifies what that trade costs and buys:
%   * matched filter (radar)            -> best SNR, needs the waveform
%   * envelope detector, 500 MHz channel -> default notional Philowave
%   * envelope detector,  50 MHz channel -> narrower filters: +10 dB
%     sensitivity, but slower rise time (TOA precision) and 10x more
%     channels to cover the same band (SWaP) -- see Mission Engineering M1
% Simulated at complex baseband around the channel center. NOTIONAL values.

setupPaths;
pw.setSeed(7);

%% 1. Waveform: LFM pulse, 10 us, 20 MHz sweep (time-bandwidth 200)
fs  = 1.2e9;                   % baseband rate covering the 500 MHz channel
tau = 10e-6; Bsw = 20e6; PRI = 60e-6;
if pw.hasToolbox('phased')
    wav = phased.LinearFMWaveform('SampleRate', fs, 'PulseWidth', tau, ...
        'SweepBandwidth', Bsw, 'PRF', 1/PRI, 'NumPulses', 1);
    s = wav();
    mfCoeff = getMatchedFilter(wav);
else
    n = (0:round(tau*fs)-1).'/fs;
    s = [exp(1i*pi*(Bsw/tau)*(n - tau/2).^2); zeros(round((PRI-tau)*fs),1)];
    mfCoeff = conj(flipud(s(1:round(tau*fs))));
end
N = numel(s); t = (0:N-1).'/fs;
d0 = 15e-6;                                        % true delay
x = circshift(s, round(d0*fs));

%% 2. Received signal: fix the in-band (500 MHz) input SNR at -5 dB
% (well below what a single-pulse envelope detector can use)
snrIn_dB = -5;
Bwide = 500e6;
noise = (randn(N,1) + 1i*randn(N,1))/sqrt(2);
noise = bandlimit(noise, fs, Bwide);                  % white over the channel
Ps = 10^(snrIn_dB/10)*var(noise);
y = sqrt(Ps)*x + noise;

%% 3a. Matched filter (the radar)
if pw.hasToolbox('phased')
    mf = phased.MatchedFilter('Coefficients', mfCoeff);
    ymf = mf(y);
    gd = numel(mfCoeff) - 1;                           % group delay (samples)
else
    ymf = filter(mfCoeff, 1, y); gd = numel(mfCoeff) - 1;
end
ymf = ymf(gd+1:end); ymf(end+1:N) = 0;
pmf = abs(ymf).^2;

%% 3b. Envelope detectors (the balloon): channel filter -> |.|^2 -> video LPF
[v500, B500] = envelopeDetect(y, fs, 500e6);
[v050, B050] = envelopeDetect(bandlimit(y, fs, 50e6), fs, 50e6);

%% 4. Compare detection quality
% Pre-detection SNR is what sets single-pulse detectability (Albersheim).
% For the video outputs we also report the DEFLECTION: (mean level during
% the pulse - mean noise level) / std(noise level), in dB.
noiseIdx = t > 35e-6;
inPulse  = t > d0 + 1e-6 & t < d0 + tau - 1e-6;
deflect  = @(v) 20*log10(max(mean(v(inPulse)) - mean(v(noiseIdx)), eps)/std(v(noiseIdx)));
fprintf('Signal: LFM %g us x %g MHz. Input SNR in the 500 MHz channel: %.1f dB\n', ...
    tau*1e6, Bsw/1e6, snrIn_dB);
fprintf('  radar matched filter: output SNR ~ %5.1f dB  (= input + 10log10(tau*B) = %.1f dB gain)\n', ...
    snrIn_dB + 10*log10(tau*Bwide), 10*log10(tau*Bwide));
fprintf('  HAB, 500 MHz channel: pre-detection SNR %5.1f dB, video deflection %5.1f dB\n', ...
    snrIn_dB, deflect(v500));
fprintf('  HAB,  50 MHz channel: pre-detection SNR %5.1f dB, video deflection %5.1f dB\n', ...
    snrIn_dB + 10*log10(Bwide/50e6), deflect(v050));
fprintf(['  -> Not knowing the waveform costs the intercept receiver ~%.0f dB versus\n' ...
         '     the radar''s matched filter; the one-way link (R2) more than pays it back.\n'], ...
    10*log10(tau*Bwide));

figure('Name','R3 matched filter vs envelope');
subplot(3,1,1); plot(t*1e6, 10*log10(pmf/mean(pmf(noiseIdx)))); grid on
title('Radar: matched filter output (dB over noise)'); ylim([-10 50]);
subplot(3,1,2); plot(t*1e6, 10*log10(v500/mean(v500(noiseIdx)))); grid on
title(sprintf('HAB: envelope detector, %.0f MHz channel', B500/1e6)); ylim([-10 25]);
subplot(3,1,3); plot(t*1e6, 10*log10(v050/mean(v050(noiseIdx)))); grid on
title(sprintf('HAB: envelope detector, %.0f MHz channel', B050/1e6)); ylim([-10 25]);
xlabel('time (\mus)');

%% 5. The channel-width trade: sensitivity vs TOA precision (strong pulse)
% Rise time of the detected envelope ~ 1/B_video limits leading-edge TOA.
y2 = x;                                   % noise-free: rise time is a filter property
Bs = [25 50 100 250 500 1000]*1e6;
fprintf('\n%10s %14s %14s %14s\n','channel','sens (dBm)','rise (ns)','ch for 16 GHz');
k = pw.const();
for B = Bs
    if B <= fs/2
        v = envelopeDetect(bandlimit(y2, fs, B), fs, B);
        pk = max(v); i10 = find(v > 0.1*pk, 1); i90 = find(v > 0.9*pk, 1);
        rise = (i90 - i10)/fs;
    else
        rise = NaN;                        % channel wider than this simulation's fs
    end
    sens = 10*log10(k.kB*k.T0*B*1e3) + 5 + pw.albersheim(0.9, 1e-9, 1);
    fprintf('%7.0f MHz %14.1f %14.1f %14d\n', B/1e6, sens, rise*1e9, ceil(16e9/B));
end
fprintf(['\nNarrow channels buy sensitivity (and finer frequency ID) at the cost of\n' ...
         'rise time and channel count. Leading-edge TOA error ~ rise/sqrt(SNR), so at\n' ...
         'mainbeam SNRs every channel >= 50 MHz stays well under the 30 ns clock error\n' ...
         'between balloons; very narrow channels (25 MHz, ~140 ns rise) start to matter.\n']);

% Helper functions bandlimit.m and envelopeDetect.m are in ./private
