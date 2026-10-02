function [nHit, isFalse] = matchTruth(toa, truth, tol)
%MATCHTRUTH Count detected pulses within tol of a true leading edge.
isFalse = true(size(toa)); hit = false(size(truth));
for i = 1:numel(toa)
    [d, j] = min(abs(truth - toa(i)));
    if d <= tol, isFalse(i) = false; hit(j) = true; end
end
nHit = nnz(hit);
end
