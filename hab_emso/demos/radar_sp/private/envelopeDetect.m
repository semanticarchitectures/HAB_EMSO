function [v, B] = envelopeDetect(x, fs, B)
%ENVELOPEDETECT Square-law detector + moving-average video filter (~B/2).
L = max(1, round(2*fs/B));
v = filter(ones(L,1)/L, 1, abs(x).^2);
end
