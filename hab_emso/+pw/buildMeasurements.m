function [meas, info] = buildMeasurements(pdw, grp, C, habLLA, rx, opts)
%PW.BUILDMEASUREMENTS Scan-timing and TDOA measurements for one associated
%   emitter group (output of pw.associateClusters).
%   [meas, info] = pw.buildMeasurements(pdw, grp, C, habLLA, rx)
%   opts.useScan (true), opts.useTDOA (true)
%   opts.scanRateSigma  assumed 1-sigma fractional rotation-rate variation
%                       within one revolution (default 0.003)
%   opts.predictedLLA   coarse position used to resolve TDOA ambiguity
%
%   meas(m): type, i, j, value (s), sigma (s, total 1-sigma), period (s,
%            scan only), n, group, sigShared
%   Errors are CORRELATED: every TDOA against the same reference HAB shares
%   that HAB's clock bias, and every scan-timing difference against the
%   same reference burst shares that burst's timing error. group/sigShared
%   carry this so pw.geolocate can weight the measurements correctly.
if nargin < 6, opts = struct(); end
if ~isfield(opts,'useScan'), opts.useScan = true; end
if ~isfield(opts,'useTDOA'), opts.useTDOA = true; end
if ~isfield(opts,'scanRateSigma'), opts.scanRateSigma = 0.003; end
k = pw.const();
meas = struct('type',{},'i',{},'j',{},'value',{},'sigma',{},'period',{},'n',{},'group',{},'sigShared',{});
info.nScan = 0; info.nTDOA = 0; info.nAmbiguous = 0;
mem = grp.members;
if size(mem,1) < 2, return; end
cl = arrayfun(@(r) C{mem(r,1)}(mem(r,2)), 1:size(mem,1));

% ---------------- scan timing (rotating emitters) --------------------------
if opts.useScan && strcmp(grp.scanType,'rotating')
    T = grp.period;
    cl = cl(arrayfun(@(c) strcmp(c.scan.scanType,'rotating'), cl));
    nb = arrayfun(@(c) numel(c.scan.tCenter), cl);
    [~, r0] = max(nb);
    ref = cl(r0);
    for b = 1:numel(ref.scan.tCenter)
        tr = ref.scan.tCenter(b); sr = ref.scan.sigmaT(b);
        for q = setdiff(1:numel(cl), r0)
            tj = cl(q).scan.tCenter; sj = cl(q).scan.sigmaT;
            w = find(tj >= tr & tj < tr + T, 1);
            if isempty(w), continue; end
            dt = tj(w) - tr;
            sg = sqrt(sr^2 + sj(w)^2 + (opts.scanRateSigma*dt)^2);
            meas(end+1) = struct('type','scan','i',ref.hab,'j',cl(q).hab, ...
                'value',dt,'sigma',sg,'period',T,'n',1,'group',100+b,'sigShared',sr); %#ok<AGROW>
            info.nScan = info.nScan + 1;
        end
    end
end

% ---------------- TDOA (pulses heard at several HABs) ----------------------
cl = arrayfun(@(r) C{mem(r,1)}(mem(r,2)), 1:size(mem,1));
if opts.useTDOA
    [~, r0] = max([cl.n]);
    ref = cl(r0);
    tRef = pdw.toa(ref.idx);
    for q = setdiff(1:numel(cl), r0)
        tJ = pdw.toa(cl(q).idx);
        base = norm(pw.lla2ecef(habLLA(ref.hab,:)) - pw.lla2ecef(habLLA(cl(q).hab,:)));
        maxLag = base/k.c + 5*rx.sigmaSync_s;
        o = struct('pri', grp.priSet);
        if isfield(opts,'predictedLLA')
            pE = pw.lla2ecef(opts.predictedLLA);
            o.predicted = (norm(pE - pw.lla2ecef(habLLA(cl(q).hab,:))) - ...
                           norm(pE - pw.lla2ecef(habLLA(ref.hab,:))))/k.c;
        end
        [td, sg, n, amb] = pw.measureTDOA(tRef, tJ, maxLag, o);
        if amb, info.nAmbiguous = info.nAmbiguous + 1; end
        if isnan(td) || n < 10 || (amb && ~isfield(o,'predicted')), continue; end
        sg = sqrt(sg^2 + 2*rx.sigmaSync_s^2);
        meas(end+1) = struct('type','tdoa','i',ref.hab,'j',cl(q).hab, ...
            'value',td,'sigma',sg,'period',NaN,'n',n,'group',1,'sigShared',rx.sigmaSync_s); %#ok<AGROW>
        info.nTDOA = info.nTDOA + 1;
    end
end
end
