function cl = deinterleave(pdw, hab, opts)
%PW.DEINTERLEAVE Sort one HAB's PDW stream into per-emitter clusters.
%   cl = pw.deinterleave(pdw, hab)
%
%   The filter-bank detector reports only channel, TOA, PW and amplitude,
%   so deinterleaving uses exactly those:
%     1. group by channel
%     2. split each channel on pulse-width gaps (> opts.pwTol relative)
%     3. drop clusters with < opts.minPulses (removes most false alarms)
%     4. PRI analysis (pw.estimatePRI) and scan analysis (pw.scanAnalysis)
%     5. merge frequency-agile emitters: clusters in different channels
%        with matching PW and overlapping PRI sets are one emitter
%
%   cl(k) fields: hab, channels, fMin/fMax (Hz, channel edges), pw (s),
%     priSet (s), idx (indices into pdw), n, scan (pw.scanAnalysis output),
%     truth (majority truth emitter index, for scoring only), purity
if nargin < 3, opts = struct(); end
if ~isfield(opts,'pwTol'),     opts.pwTol = 0.25; end
if ~isfield(opts,'minPulses'), opts.minPulses = 20; end
rx = [];
if isfield(opts,'rx'), rx = opts.rx; end

sel = find(pdw.hab == hab);
cl = struct('hab',{},'channels',{},'fMin',{},'fMax',{},'pw',{},'priSet',{}, ...
            'idx',{},'n',{},'scan',{},'truth',{},'purity',{});
raw = {};
for c = unique(pdw.ch(sel)).'
    ii = sel(pdw.ch(sel) == c);
    [pws, o] = sort(pdw.pw(ii)); ii = ii(o);
    brk = [0; find(diff(pws) > opts.pwTol*max(pws(1:end-1), 50e-9)); numel(pws)];
    for b = 1:numel(brk)-1
        jj = ii(brk(b)+1:brk(b+1));
        if numel(jj) >= opts.minPulses
            raw{end+1} = struct('ch', c, 'idx', sort(jj)); %#ok<AGROW>
        end
    end
end

for r = 1:numel(raw)
    jj = raw{r}.idx;
    k = numel(cl) + 1;
    cl(k).hab = hab;
    cl(k).channels = raw{r}.ch;
    cl(k).pw = median(pdw.pw(jj));
    cl(k).idx = jj;
    cl(k).n = numel(jj);
    % PRI from the strongest pulses (sidelobe trains are gappy)
    a = pdw.amp(jj); strong = a >= max(a) - 15;
    cl(k).priSet = pw.estimatePRI(pdw.toa(jj(strong)));
    cl(k).scan = pw.scanAnalysis(pdw.toa(jj), pdw.amp(jj));
end

% ---- merge frequency-agile clusters ---------------------------------------
merged = true;
while merged
    merged = false;
    for a = 1:numel(cl)
        for b = a+1:numel(cl)
            if isAgilePair(cl(a), cl(b))
                cl(a).channels = union(cl(a).channels, cl(b).channels);
                cl(a).idx = sort([cl(a).idx; cl(b).idx]);
                cl(a).n = numel(cl(a).idx);
                cl(a).priSet = uniqueTol([cl(a).priSet cl(b).priSet], 0.01);
                cl(a).scan = pw.scanAnalysis(pdw.toa(cl(a).idx), pdw.amp(cl(a).idx));
                cl(b) = [];
                merged = true;
                break
            end
        end
        if merged, break; end
    end
end

% ---- frequency agility is strong evidence of electronic scanning ----------
% (a mechanically rotating magnetron/TWT radar does not hop across filter
% channels). Stepping between adjacent ESA beam positions can mimic a
% swept beam in amplitude, so agility overrides the shape test.
for k = 1:numel(cl)
    if numel(cl(k).channels) > 1 && strcmp(cl(k).scan.scanType,'rotating')
        cl(k).scan.scanType = 'raster';
        cl(k).scan.beamwidth_deg = NaN;
    end
end

% ---- channel edges and truth scoring --------------------------------------
for k = 1:numel(cl)
    if ~isempty(rx)
        cl(k).fMin = rx.fEdges(min(cl(k).channels));
        cl(k).fMax = rx.fEdges(max(cl(k).channels)+1);
    end
    tr = pdw.emitter(cl(k).idx);
    u = unique(tr); cnt = arrayfun(@(x) nnz(tr==x), u);
    [mx, im] = max(cnt);
    cl(k).truth = u(im); cl(k).purity = mx/numel(tr);
end
end

function tf = isAgilePair(A, B)
tf = false;
if any(ismember(A.channels, B.channels)), return; end
if abs(A.pw - B.pw) > 0.15*max(A.pw, B.pw), return; end
if isempty(A.priSet) || isempty(B.priSet), return; end
% overlapping PRI sets (within 1 %)
for p = A.priSet
    if any(abs(B.priSet - p) < 0.01*p), tf = true; return; end
end
end

function u = uniqueTol(v, rtol)
% unique values within a relative tolerance (keeps the first of each group)
v = sort(v(:)).'; u = [];
for x = v
    if isempty(u) || abs(x - u(end)) > rtol*x, u(end+1) = x; end %#ok<AGROW>
end
end
