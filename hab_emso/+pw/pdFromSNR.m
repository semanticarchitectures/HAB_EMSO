function Pd = pdFromSNR(snr_dB, Pfa, N)
%PW.PDFROMSNR Probability of detection from SNR by inverting Albersheim.
%   Pd = pw.pdFromSNR(snr_dB, Pfa, N)  (element-wise)
if nargin < 3, N = 1; end
A = log(0.62./Pfa);
Z = (snr_dB + 5*log10(N)) ./ (6.2 + 4.54./sqrt(N+0.44));
B = (10.^Z - A) ./ (0.12*A + 1.7);
Pd = 1./(1+exp(-B));
end
