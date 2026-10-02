function [det, thr] = caCFAR(x, nTrain, nGuard, Pfa)
%PW.CACFAR Cell-averaging CFAR on a square-law (power) sequence.
%   [det, thr] = pw.caCFAR(x, nTrain, nGuard, Pfa)
%     x       power samples (column), exponential-distributed noise assumed
%     nTrain  training cells on EACH side; nGuard guard cells on each side
%   Threshold factor for N averaged cells: alpha = N*(Pfa^(-1/N) - 1).
%   Toolbox equivalent: phased.CFARDetector('Method','CA', ...).
%   NOTE: detector video is correlated over ~1/Bvideo, so decimate to about
%   one sample per 1/Bvideo before applying the exponential-noise formula.
x = x(:); n = numel(x);
c = cumsum([0; x]);
thr = inf(n,1);
for i = 1:n
    lo1 = i - nGuard - nTrain; hi1 = i - nGuard - 1;
    lo2 = i + nGuard + 1;      hi2 = i + nGuard + nTrain;
    s = 0; m = 0;
    if lo1 >= 1, s = s + c(hi1+1) - c(lo1); m = m + nTrain; end
    if hi2 <= n, s = s + c(hi2+1) - c(lo2); m = m + nTrain; end
    if m > 0, thr(i) = m*(Pfa^(-1/m) - 1)*s/m; end   % one-sided at the edges
end
det = x > thr;
end
