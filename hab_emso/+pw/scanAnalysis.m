function sa = scanAnalysis(toa, amp, opts)
%PW.SCANANALYSIS Illumination (mainbeam) bursts and scan type from a pulse
%   train seen by one receiver.
%   sa = pw.scanAnalysis(toa, amp)
%
%   Method
%     1. keep pulses within opts.mbWindow_dB (default 12 dB) of the train's
%        peak amplitude (mainbeam region; sidelobe pulses are ignored)
%     2. split into bursts at gaps > opts.gap_s (default 20 ms)
%     3. fit a parabola to amplitude(dB) vs time in each burst; for a
%        Gaussian-shaped beam the vertex is the beam-center crossing time
%     4. burst SHAPE: a mechanically rotating beam sweeps past the receiver
%        (amplitude rises and falls ~ Gaussian); an electronically steered
%        beam dwells (flat top, abrupt edges). Median in-burst amplitude
%        span < 6 dB => 'stepped' (electronic).
%     5. regular burst spacing (CV < 5 %) + swept shape => 'rotating',
%        period = median spacing (after folding out missed revolutions);
%        regular + stepped => 'raster' (periodic ESA search);
%        otherwise 'irregular'
%
%   sa fields: tCenter (s), sigmaT (s), peak_dBm, dur3dB (s), nPulses,
%              span_dB (in-burst amplitude span),
%              scanType ('rotating'|'raster'|'irregular'|'unknown'), period (s),
%              beamwidth_deg (rotating only)
if nargin < 3, opts = struct(); end
if ~isfield(opts,'mbWindow_dB'), opts.mbWindow_dB = 12; end
if ~isfield(opts,'gap_s'),       opts.gap_s = 20e-3; end
if ~isfield(opts,'minPulses'),   opts.minPulses = 4; end

[toa, o] = sort(toa(:)); amp = amp(o); amp = amp(:);
sa = struct('tCenter',[],'sigmaT',[],'peak_dBm',[],'dur3dB',[],'nPulses',[],'span_dB',[], ...
            'scanType','unknown','period',NaN,'beamwidth_deg',NaN);
if numel(toa) < opts.minPulses, return; end

% robust peak: 3rd-highest amplitude (mainbeam pulses can be <1 % of a
% train dominated by sidelobe intercepts, so percentiles fail)
sa_ = sort(amp); pk = sa_(max(1, numel(sa_)-2));
m = amp >= pk - opts.mbWindow_dB;
t = toa(m); a = amp(m);
if numel(t) < opts.minPulses, return; end
brk = [0; find(diff(t) > opts.gap_s); numel(t)];
for b = 1:numel(brk)-1
    ii = brk(b)+1:brk(b+1);
    if numel(ii) < opts.minPulses, continue; end
    tb = t(ii); ab = a(ii);
    tm = mean(tb);  ts = max(std(tb), 1e-6);
    x  = (tb - tm)/ts;
    A  = [x.^2, x, ones(size(x))];
    c  = A\ab;
    if c(1) < 0
        xv = -c(2)/(2*c(1));
        if abs(xv) > 3, xv = (sum(10.^(ab/10).*x)/sum(10.^(ab/10))); end
        tc = tm + xv*ts;
        pkv = c(3) - c(2)^2/(4*c(1));
        w3 = 2*sqrt(3/abs(c(1)))*ts;       % -3 dB full width
        res = ab - A*c;
        s_a = max(std(res), 0.3);
        % vertex uncertainty (first-order): sigma_t ~ w3 * s_a / (3*sqrt(N))
        sT = w3*s_a/(3*sqrt(numel(ii)));
    else   % flat / truncated burst: power-weighted centroid
        wts = 10.^(ab/10);
        tc = sum(wts.*tb)/sum(wts); pkv = max(ab);
        w3 = max(tb)-min(tb); sT = max(w3/sqrt(12*numel(ii)), 1e-5);
    end
    sa.tCenter(end+1,1) = tc; sa.sigmaT(end+1,1) = sT;
    sa.peak_dBm(end+1,1) = pkv; sa.dur3dB(end+1,1) = w3;
    sa.nPulses(end+1,1) = numel(ii);
    sa.span_dB(end+1,1) = max(ab) - min(ab);
end
nb = numel(sa.tCenter);
stepped = nb >= 1 && median(sa.span_dB) < 6;
if nb >= 3
    dt = diff(sa.tCenter);
    base = min(dt(dt > 0.2*median(dt)));
    nrev = max(1, round(dt/base));          % fold out missed revolutions
    per  = dt./nrev;
    if std(per)/mean(per) < 0.05 && stepped
        sa.scanType = 'raster';
        sa.period = median(per);
    elseif std(per)/mean(per) < 0.05
        sa.scanType = 'rotating';
        sa.period = median(per);
        sa.beamwidth_deg = 360*median(sa.dur3dB)/sa.period;
    else
        sa.scanType = 'irregular';
    end
elseif nb >= 1
    sa.scanType = 'irregular';
end
end
