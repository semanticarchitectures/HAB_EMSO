function snr_dB = albersheim(Pd, Pfa, N)
%PW.ALBERSHEIM Required SNR (dB) for a nonfluctuating target, square-law
%   detector, N noncoherently integrated pulses (Albersheim's equation).
%   Valid ~ 0.1<=Pd<=0.9999, 1e-7<=Pfa<=1e-3 (usable slightly beyond).
%   Toolbox equivalent: albersheim(Pd,Pfa,N) in Radar Toolbox /
%   Phased Array System Toolbox.
if nargin < 3, N = 1; end
A = log(0.62./Pfa);
B = log(Pd./(1-Pd));
snr_dB = -5*log10(N) + (6.2 + 4.54./sqrt(N+0.44)) .* log10(A + 0.12*A.*B + 1.7*B);
end
