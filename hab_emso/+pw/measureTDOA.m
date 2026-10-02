function [tdoa, sigma, nMatch, ambiguous] = measureTDOA(toaRef, toaJ, maxLag, opts)
%PW.MEASURETDOA Time difference of arrival between two HABs from pulse
%   trains of the same emitter (pulse-to-pulse association by histogram).
%   [tdoa, sigma, nMatch, ambiguous] = pw.measureTDOA(toaRef, toaJ, maxLag)
%     tdoa   = t_J - t_Ref (s) for the same transmitted pulse
%     maxLag = |max possible TDOA| = baseline/c + clock margin (s)
%
%   Every pulse pair within +-maxLag votes in a histogram. The true delay
%   collects a vote from every common pulse; wrong pairings spread out.
%   With a CONSTANT PRI shorter than 2*maxLag, several peaks tie at
%   tdoa + k*PRI: the result is flagged ambiguous. Staggered or jittered
%   PRIs remove the ambiguity. opts.predicted (s) picks the peak nearest a
%   predicted value (e.g., from a scan-timing fix) to resolve it.
%   opts.pri (s): the emitter's PRI set; a single PRI shorter than
%   2*maxLag forces the ambiguous flag even if one peak looks dominant.
if nargin < 4, opts = struct(); end
if ~isfield(opts,'bin'), opts.bin = 100e-9; end
tdoa = NaN; sigma = NaN; nMatch = 0; ambiguous = false;
a = sort(toaRef(:)); b = sort(toaJ(:));
if numel(a) < 5 || numel(b) < 5, return; end
a = unique(a);
lo = countLE(a, b - maxLag - 1e-12) + 1;
hi = countLE(a, b + maxLag);
D = [];
for m = 0:max(hi - lo)
    k = lo + m; ok = k <= hi;
    D = [D; b(ok) - a(k(ok))]; %#ok<AGROW>
end
if isempty(D), return; end
edges = -maxLag:opts.bin:maxLag;
h = histc(D, edges); h = h(:);
[srt, o] = sort(h, 'descend');
pk = o(1);
% ambiguity: another well-separated peak with a meaningful share of the
% votes, or a known constant PRI shorter than the lag window (then
% tdoa + k*PRI are all physically possible and sparse sidelobe matches can
% make the wrong one win by chance)
far = abs(o - pk) > 3;
strongFar = far & srt >= 0.3*srt(1);
if any(strongFar), ambiguous = true; end
if isfield(opts,'pri') && ~isempty(opts.pri) && numel(opts.pri) == 1 && 2*maxLag > opts.pri
    ambiguous = true;
end
if ambiguous && isfield(opts,'predicted') && ~isnan(opts.predicted)
    cands = [pk; o(strongFar)];
    [~, ib] = min(abs(edges(cands) + opts.bin/2 - opts.predicted));
    pk = cands(ib);
end
c = edges(pk) + opts.bin/2;
sel = abs(D - c) <= 2*opts.bin;
nMatch = nnz(sel);
if nMatch < 3, tdoa = NaN; return; end
v = D(sel);
tdoa = median(v);
sigma = 1.2533*std(v)/sqrt(nMatch);   % statistical part only (see note)
% NOTE: the clock (synchronization) error between the two HABs does NOT
% average down over pulses. pw.geolocate adds rx.sigmaSync_s in quadrature.
end

function n = countLE(a, x)
% Number of elements of sorted, unique vector a that are <= x.
xs = min(max(x, a(1)-1), a(end)+1);
n = interp1([a(1)-1; a; a(end)+1], [0; (1:numel(a)).'; numel(a)], xs, 'previous');
end
