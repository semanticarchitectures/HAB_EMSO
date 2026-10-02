function [priSet, counts] = estimatePRI(toa, opts)
%PW.ESTIMATEPRI PRI values present in a pulse train (difference histogram).
%   priSet = pw.estimatePRI(toa)
%   Consecutive-difference histogram (a simplified CDIF). Peaks that are
%   integer multiples of a smaller peak (missed pulses) are suppressed.
%   opts.binWidth (s, default 0.5 us), opts.maxPRI (s, default 5 ms),
%   opts.minFrac (default 0.04) minimum fraction of differences in a peak.
if nargin < 2, opts = struct(); end
if ~isfield(opts,'binWidth'), opts.binWidth = 0.5e-6; end
if ~isfield(opts,'maxPRI'),   opts.maxPRI = 5e-3; end
if ~isfield(opts,'minFrac'),  opts.minFrac = 0.04; end
d = diff(sort(toa(:)));
d = d(d > 2e-6 & d < opts.maxPRI);
priSet = []; counts = [];
if numel(d) < 5, return; end
edges = 0:opts.binWidth:opts.maxPRI;
h = histc(d, edges); h = h(:).';
thr = max(3, opts.minFrac*numel(d));
cand = find(h >= thr & h >= [0 h(1:end-1)] & h >= [h(2:end) 0]);
if isempty(cand), return; end
% refine each candidate with the mean of differences in +-1 bin
vals = zeros(size(cand)); cnt = vals;
for i = 1:numel(cand)
    c = edges(cand(i)) + opts.binWidth/2;
    m = abs(d - c) <= 1.5*opts.binWidth;
    vals(i) = mean(d(m)); cnt(i) = nnz(m);
end
% merge near-duplicates (adjacent bins)
[vals, o] = sort(vals); cnt = cnt(o);
keep = true(size(vals));
for i = 2:numel(vals)
    if vals(i) - vals(i-1) < 2*opts.binWidth
        keep(i) = false; cnt(i-1) = cnt(i-1) + cnt(i);
    end
end
vals = vals(keep); cnt = cnt(keep);
% suppress harmonics / sums of smaller PRIs (missed-pulse artifacts)
keep = true(size(vals));
for i = 1:numel(vals)
    for j = 1:i-1
        if ~keep(j), continue; end
        for m = 2:6
            if abs(vals(i) - m*vals(j)) < 3*opts.binWidth*m, keep(i) = false; end
        end
        for jj = 1:i-1   % sums of two base PRIs (one missed pulse in a stagger)
            if abs(vals(i) - vals(j) - vals(jj)) < 4*opts.binWidth, keep(i) = false; end
        end
    end
end
priSet = vals(keep); counts = cnt(keep);
end
