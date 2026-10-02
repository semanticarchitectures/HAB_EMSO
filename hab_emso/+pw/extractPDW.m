function P = extractPDW(v, tv, thr, mergeGap_s)
%PW.EXTRACTPDW Pulse descriptor words from one channel's video signal.
%   P = pw.extractPDW(v, tv, thr)
%   P = pw.extractPDW(v, tv, thr, mergeGap_s)
%     v    video samples; tv sample times (s); thr threshold (scalar or
%          vector the size of v, e.g. from a CFAR detector)
%     mergeGap_s  threshold-crossing runs closer than this are one pulse
%                 (noise dips inside a pulse); default 30 ns
%   P.toa   leading-edge time: interpolated crossing of 50 % of the pulse
%           PLATEAU (median level over the pulse), not of its noisy peak
%   P.pw    width between the leading and trailing 50 % crossings (s)
%   P.peak  peak video level;  P.level  plateau (median) level
if nargin < 4, mergeGap_s = 30e-9; end
v = v(:); tv = tv(:); n = numel(v);
if isscalar(thr), thr = thr*ones(size(v)); end
dt = tv(2) - tv(1);
above = v > thr(:);
d = diff([false; above; false]);
st = find(d == 1); en = find(d == -1) - 1;
% merge runs separated by short gaps
if numel(st) > 1
    keep = [true; (st(2:end) - en(1:end-1))*dt > mergeGap_s];
    grp = cumsum(keep);
    st = accumarray(grp, st, [], @min);
    en = accumarray(grp, en, [], @max);
end
P.toa = zeros(numel(st),1); P.pw = P.toa; P.peak = P.toa; P.level = P.toa;
for i = 1:numel(st)
    seg = st(i):en(i);
    lvl = median(v(seg)); half = lvl/2;
    % leading edge: a = last sample below half before the plateau
    a = st(i);
    if v(a) >= half
        while a > 1 && v(a) >= half, a = a - 1; end        % walk out (weak pulse)
    else
        while a < en(i) && v(a+1) < half, a = a + 1; end   % walk in (strong pulse)
    end
    % trailing edge: b = first sample below half after the plateau
    b = en(i);
    if v(b) >= half
        while b < n && v(b) >= half, b = b + 1; end
    else
        while b > st(i) && v(b-1) < half, b = b - 1; end
    end
    a = min(max(a,1), n-1); b = min(max(b,2), n);
    ta = tv(a); tb = tv(b);
    if v(a+1) ~= v(a), ta = tv(a) + (half - v(a))/(v(a+1) - v(a))*dt; end
    if v(b) ~= v(b-1), tb = tv(b-1) + (half - v(b-1))/(v(b) - v(b-1))*dt; end
    P.toa(i) = ta; P.pw(i) = tb - ta; P.peak(i) = max(v(seg)); P.level(i) = lvl;
end
end
