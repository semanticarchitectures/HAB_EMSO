function rx = defaultReceiver(nChannels, fLow, fHigh)
%PW.DEFAULTRECEIVER Notional Philowave-class filter-bank detector payload.
%   rx = pw.defaultReceiver()            32 contiguous channels, 2-18 GHz
%   rx = pw.defaultReceiver(nCh)         nCh channels across 2-18 GHz
%   rx = pw.defaultReceiver(nCh, fLo, fHi)
%
%   *** ALL VALUES ARE NOTIONAL. *** They are chosen to be physically
%   plausible for a filter-bank + envelope-detector receiver and are NOT
%   Philowave specifications. Public information: 2-4 octaves of
%   instantaneous bandwidth, sub-microsecond response, 15 GHz instantaneous
%   bandwidth goal (USAF SBIR "Wideband Interference Detector").
%
%   Architecture modeled
%     antenna -> LNA -> bank of narrowband bandpass filters ->
%     square-law (envelope) detector per channel -> video filter ->
%     threshold comparator -> pulse descriptor word (PDW) formation
%   There is no digitizer of the RF, so no phase, no fine frequency, and no
%   single-platform angle of arrival. Each channel reports only
%   time of arrival (TOA), pulse width (PW), amplitude and channel index.
%
%   Fields (SI units unless noted)
%     fEdges        channel edges (Hz), 1-by-(nCh+1)
%     fCenter, B    channel centers and noise bandwidths (Hz)
%     Bvideo        video bandwidth (Hz), ~B/2
%     NF_dB         cascade noise figure
%     Grx_dBi       antenna gain toward the horizon (wide-beam, down-looking)
%     Lpol_dB       polarization mismatch (linear emitter, circular HAB ant.)
%     Lfilt_dB      filter insertion loss
%     Pfa           false-alarm probability per video sample
%     Pd            design detection probability
%     SNRreq_dB     single-pulse SNR required (Albersheim) for Pd/Pfa
%     sens_dBm      per-channel sensitivity at the antenna port
%     sigmaSync_s   inter-platform clock error (GPS-disciplined), 1-sigma
%     sigmaPos_m    platform position error (GNSS), 1-sigma per axis
%     sigmaAmp_dB   amplitude measurement error, 1-sigma
%     power_W, mass_kg, unitCost_USD   SWaP-C scaling model (notional)

if nargin < 1 || isempty(nChannels), nChannels = 32; end
if nargin < 2 || isempty(fLow),  fLow  = 2e9;  end
if nargin < 3 || isempty(fHigh), fHigh = 18e9; end

k = pw.const();
rx.name      = sprintf('Notional Philowave-class detector (%d ch, %.0f-%.0f GHz)', ...
                       nChannels, fLow/1e9, fHigh/1e9);
rx.nChannels = nChannels;
rx.fEdges    = linspace(fLow, fHigh, nChannels+1);
rx.fCenter   = (rx.fEdges(1:end-1)+rx.fEdges(2:end))/2;
rx.B         = diff(rx.fEdges);
rx.Bvideo    = rx.B/2;
rx.NF_dB     = 5;
rx.Grx_dBi   = 0;
rx.Lpol_dB   = 3;
rx.Lfilt_dB  = 1.5;
rx.Pfa       = 1e-9;
rx.Pd        = 0.9;
rx.SNRreq_dB = pw.albersheim(rx.Pd, rx.Pfa, 1);
rx.noise_dBm = 10*log10(k.kB*k.T0*rx.B*1e3) + rx.NF_dB;       % per channel
rx.sens_dBm  = rx.noise_dBm + rx.SNRreq_dB;                     % at LNA input
rx.sigmaSync_s = 30e-9;
rx.sigmaPos_m  = 5;
rx.sigmaAmp_dB = 1.5;
rx.pulseRes_s  = 1/mean(rx.Bvideo);          % ~pulse-edge resolution

% --- SWaP-C scaling (notional) ------------------------------------------
% Fixed core (LNA, GNSS/timing, processor, datalink) + per-channel filter/
% detector slice. Narrower channels need higher-Q filters: cost per slice
% rises as channels get narrower.
fracBW = mean(rx.B ./ rx.fCenter);
rx.power_W      = 4.0 + 0.25*nChannels;
rx.mass_kg      = 0.8 + 0.04*nChannels;
rx.unitCost_USD = 15e3 + nChannels*(600 + 40/max(fracBW,0.005));
end
