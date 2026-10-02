%% R2 - Radar Equation and the Intercept Receiver's One-Way Advantage
% Seminar: Introduction to Radar Signal Processing with MATLAB and Simulink
% Topics:  radar equation, detection statistics (Pd/Pfa), range estimation
%
% The radar must detect a two-way echo (SNR falls as 1/R^4) and it
% integrates many pulses with a matched filter. The balloon's detector
% hears the one-way transmission (1/R^2) with no matched filter and no
% integration. This demo compares, for each notional emitter:
%   * the radar's own detection range against a 1 m^2 target
%   * the HAB's intercept range of that radar (mainbeam and sidelobes)
% ALL PARAMETERS ARE NOTIONAL.

setupPaths;
rx  = pw.defaultReceiver();
lib = pw.emitterLibrary();
k   = pw.const();
habAlt = 20e3;

%% 1. Radar-side assumptions (notional)
Pd = 0.9; PfaRadar = 1e-6; rcs = 1;       % 1 m^2 target
NF_radar = 4; Ls_radar = 6;                % noise figure, system losses (dB)
fprintf('Radar: Pd %.2f, Pfa %.0e, RCS %g m^2, NF %g dB, losses %g dB\n', ...
    Pd, PfaRadar, rcs, NF_radar, Ls_radar);
fprintf('HAB detector: %d ch x %.0f MHz, NF %g dB, Pfa %.0e -> sensitivity %.1f dBm\n\n', ...
    rx.nChannels, rx.B(1)/1e6, rx.NF_dB, rx.Pfa, rx.sens_dBm(1));

%% 2. Two-way radar range vs one-way intercept range
fprintf('%-7s %11s %11s %13s %13s %9s\n','emitter','Nint','R_radar', ...
    'R_int (main)','R_int (side)','ratio');
res = zeros(numel(lib),3);
for i = 1:numel(lib)
    L = lib(i); lam = k.c/L.fc;
    % pulses integrated on target during one beam dwell
    if strcmp(L.scanType,'rotating')
        tDwell = L.azBW_deg/360*L.scanPeriod_s;
    else
        tDwell = L.esaDwell_s;
    end
    Nint = max(1, floor(tDwell/mean(L.PRI_s)));
    SNRreq = pw.albersheim(Pd, PfaRadar, Nint);         % per-pulse, noncoherent
    % single-pulse SNR from the radar equation (matched filter: B*tau ~ 1)
    Pt = L.Ppeak_W; G = 10^(L.G_dBi/10); Tn = k.T0*10^(NF_radar/10);
    Rr = ((Pt*G^2*lam^2*rcs*L.PW_s) / ((4*pi)^3*k.kB*Tn*10^(Ls_radar/10)* ...
          10^(SNRreq/10)))^(1/4);
    if pw.hasToolbox('radar')
        % Radar Toolbox cross-check (same assumptions)
        Rr_tb = radareqrng(lam, SNRreq, Pt, L.PW_s, 'Gain', L.G_dBi, 'RCS', rcs, ...
            'Ts', Tn, 'Loss', Ls_radar);
        Rr = Rr_tb;
    end
    Rm = pw.interceptRange(L, rx, habAlt, L.antHeight_m, 'main');
    Rs = pw.interceptRange(L, rx, habAlt, L.antHeight_m, 'side');
    res(i,:) = [Rr Rm Rs];
    fprintf('%-7s %11d %9.0f km %10.0f km %10.0f km %8.1fx\n', L.id, Nint, Rr/1e3, ...
        Rm/1e3, Rs/1e3, Rm/Rr);
end
fprintf('\nIntercept ranges are capped by the 20 km balloon''s radio horizon (~%0.f km).\n', ...
    (sqrt(2*k.kEff*k.Re*habAlt))/1e3);

%% 3. SNR vs range: two-way echo against one-way intercept (X-band marine)
L = lib(strcmp({lib.id},'MAR-X1')); lam = k.c/L.fc;
R = logspace(3, log10(700e3), 400);
Tn = k.T0*10^(NF_radar/10);
snrRadar = 10*log10(L.Ppeak_W*10^(2*L.G_dBi/10)*lam^2*rcs*L.PW_s ./ ...
    ((4*pi)^3*R.^4*k.kB*Tn*10^(Ls_radar/10)));
ch = pw.channelOf(L.fc, rx);
prx = 10*log10(L.Ppeak_W*1e3) + L.G_dBi + rx.Grx_dBi - pw.fspl(L.fc, R) - rx.Lpol_dB - rx.Lfilt_dB;
snrMain = prx - rx.noise_dBm(ch);
snrSide = snrMain + L.SLL_dB;
figure('Name','R2 one-way advantage');
semilogx(R/1e3, snrRadar, R/1e3, snrMain, R/1e3, snrSide, 'LineWidth', 1.3); hold on
semilogx(R([1 end])/1e3, pw.albersheim(Pd,PfaRadar,1)*[1 1], 'k--');
semilogx(R([1 end])/1e3, rx.SNRreq_dB*[1 1], 'k:');
grid on; xlabel('range (km)'); ylabel('single-pulse SNR (dB)');
legend('radar echo, 1 m^2 (R^{-4})','HAB intercept, mainbeam (R^{-2})', ...
    'HAB intercept, sidelobes','radar threshold','HAB threshold','Location','southwest');
title('MAR-X1: the intercept receiver hears the radar long before the radar sees it');

%% 4. Take-away
% Even with no matched filter and a 500 MHz noise bandwidth, the balloon
% hears mainbeam illumination far beyond the radar's own detection range,
% so the practical limit is the horizon. Sidelobe intercepts -- which are
% what TDOA geolocation needs at three balloons at once -- are a different
% story for low-power or low-sidelobe radars (see R5 and the EMSO demos).
