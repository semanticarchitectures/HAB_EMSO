%% R5 - Spatial Processing: Beam Steering, Sidelobes, and DOA for the HAB
% Seminar: Introduction to Radar Signal Processing with MATLAB and Simulink
% Topics:  beamforming, array tapering, DOA estimation
%
% Two sides of spatial processing matter to the balloons:
%  (1) the EMITTER's array. An AESA steers its beam electronically, suffers
%      scan loss off broadside, and uses amplitude tapering for very low
%      sidelobes. Low sidelobes are why filter-bank balloons cannot hear
%      the fighter radar at three balloons at once (no TDOA).
%  (2) the RECEIVER's direction finding. The notional Philowave payload has
%      no phase, so classical interferometry/MUSIC is out. Amplitude-
%      comparison DF (four squinted antennas, each with its own detector)
%      IS compatible with envelope detection. This demo estimates its
%      bearing accuracy, which feeds the DF option in Mission Engineering.
% NOTIONAL values.

setupPaths;
pw.setSeed(5);
k = pw.const();

%% 1. AESA beam steering, scan loss and taper (emitter side)
f = 9.8e9; lam = k.c/f; Nel = 32; d = lam/2;
az = linspace(-90, 90, 3601);
steer = [0 30 55];
figure('Name','R5 AESA patterns');
if pw.hasToolbox('phased')
    arrU = phased.ULA('NumElements',Nel,'ElementSpacing',d, ...
        'Element', phased.CosineAntennaElement('CosinePower',[1.5 1.5]));
    arrT = phased.ULA('NumElements',Nel,'ElementSpacing',d, ...
        'Element', phased.CosineAntennaElement('CosinePower',[1.5 1.5]), ...
        'Taper', taylorwin(Nel, 5, -35));
    sv = phased.SteeringVector('SensorArray', arrT);
    for q = 1:numel(steer)
        w = sv(f, [steer(q); 0]);
        p = pattern(arrT, f, az, 0, 'Weights', w, 'Type','powerdb');
        plot(az, p, 'LineWidth', 1.1); hold on
    end
    wU = phased.SteeringVector('SensorArray', arrU); wU = wU(f, [0;0]);
    pU = pattern(arrU, f, az, 0, 'Weights', wU, 'Type','powerdb');
    plot(az, pU, 'k:');
    legend('Taylor -35 dB, 0 deg','Taylor, 30 deg','Taylor, 55 deg','uniform, 0 deg');
else
    n = (0:Nel-1).' - (Nel-1)/2;
    wT = taylorTaper(Nel, 35);
    for q = 1:numel(steer)
        AF = abs(sum(bsxfun(@times, wT.*exp(-1i*2*pi*d/lam*n*sind(steer(q))), ...
             exp(1i*2*pi*d/lam*n*sind(az))),1)).^2;
        el = cosd(az).^1.5;                           % element pattern
        p = 10*log10(AF.*el.^2/max(AF)); plot(az, p, 'LineWidth', 1.1); hold on
    end
    AFu = abs(sum(exp(1i*2*pi*d/lam*n*sind(az)),1)).^2;
    plot(az, 10*log10(AFu.*cosd(az).^3/max(AFu)), 'k:');
    legend('Taylor -35 dB, 0 deg','Taylor, 30 deg','Taylor, 55 deg','uniform, 0 deg');
end
grid on; ylim([-60 3]); xlabel('azimuth (deg)'); ylabel('dB');
title('AESA: steering, scan loss and low sidelobes (32 elements, X-band)');

%% 2. What the sidelobe level means for the balloons (link budget)
rx = pw.defaultReceiver(); lib = pw.emitterLibrary();
L = lib(strcmp({lib.id},'AIR-X1'));
SLL = [-20 -25 -30 -35 -40];
fprintf('\nAIR-X1 sidelobe intercept range vs sidelobe level (20 km HAB):\n');
for s = SLL
    L.SLL_dB = s;
    R = pw.interceptRange(L, rx, 20e3, 8000, 'side');
    fprintf('  SLL %4d dB -> %6.1f km\n', s, R/1e3);
end
fprintf(['TDOA needs the same pulse at >= 3 balloons ~80+ km apart, so even a\n' ...
         '-25 dB AESA is heard in sidelobes only by nearby balloons.\n']);

%% 3. Amplitude-comparison DF on the balloon (receiver side)
% Four antennas squinted at 0/90/180/270 deg, Gaussian beams with 3-dB
% beamwidth bw; each feeds its own envelope detector. Bearing from the
% ratio of the two strongest ports:  log-ratio is linear in angle.
bw = 90; sq = [0 90 180 270];
g  = @(th) -12*((mod(bsxfun(@minus, th(:), sq) + 180, 360) - 180)/bw).^2;  % dB
snr = [10 15 20 25 30];
nTrial = 4000;
rmsErr = zeros(size(snr));
for q = 1:numel(snr)
    th = 360*rand(nTrial,1);
    Gd = g(th);                                     % dB per port
    sigA = 4.34/sqrt(10^(snr(q)/10));               % amplitude error (dB) at this SNR
    meas = Gd + sigA*randn(size(Gd)) + 0.7*randn(size(Gd));   % + 0.7 dB port mismatch
    [~, o] = sort(meas, 2, 'descend');
    est = zeros(nTrial,1);
    for n = 1:nTrial
        a = o(n,1); b = o(n,2);
        if abs(mod(sq(b)-sq(a)+180,360)-180) ~= 90   % use adjacent pair
            nb = mod([a-2 a], 4) + 1;
            [~, ii] = max(meas(n, nb)); b = nb(ii);
        end
        dlt = mod(sq(b) - sq(a) + 180, 360) - 180;      % +-90
        % Gaussian beams: ratio(dB) = (24/bw^2)*sq_sep*(theta - mid) -> linear
        mid = sq(a) + dlt/2;
        r = meas(n,a) - meas(n,b);
        est(n) = mid - sign(dlt)*r*bw^2/(24*abs(dlt));
    end
    e = mod(est - th + 180, 360) - 180;
    rmsErr(q) = sqrt(mean(e.^2));
end
figure('Name','R5 amplitude-comparison DF');
plot(snr, rmsErr, 'o-', 'LineWidth', 1.3); grid on
xlabel('per-port SNR (dB)'); ylabel('RMS bearing error (deg)');
title('4-port amplitude-comparison DF (no phase needed)');
fprintf('\nAmplitude-comparison DF RMS error: %s deg at SNR %s dB\n', ...
    mat2str(round(rmsErr*10)/10), mat2str(snr));
fprintf(['Mainbeam intercepts arrive at 20-40 dB SNR, where port mismatch sets\n' ...
         'a floor of a few degrees -- the value (6 deg) assumed by the Mission\n' ...
         'Engineering DF option is deliberately conservative.\n']);

% Helper taylorTaper.m (used without the toolbox) is in ./private
