function pdw = generatePDWs(scn, t0, dur, opts)
%PW.GENERATEPDWS Measurement-level pulse intercepts at every HAB.
%   pdw = pw.generatePDWs(scn, t0, dur)
%   pdw = pw.generatePDWs(scn, t0, dur, opts)
%
%   Simulates every transmitted pulse from every emitter in [t0, t0+dur),
%   evaluates the one-way link to each HAB (antenna scan pattern, free-space
%   loss, horizon), draws detections from Pd(SNR), and forms the pulse
%   descriptor words (PDWs) the notional filter-bank detector would report.
%
%   opts (all optional)
%     seed           RNG seed (default scn.seed)
%     emitters       indices of emitters to include (default all)
%     habs           indices of HABs to include (default all)
%     falseAlarms    true to add threshold-crossing noise PDWs (default true)
%
%   pdw is a struct of column vectors, sorted by (hab, toa):
%     hab    HAB index            toa   measured time of arrival (s)
%     ch     filter channel       pw    measured pulse width (s)
%     amp    measured power at the antenna port (dBm)
%     snr    true SNR (dB)        -- truth, for scoring only --
%     emitter  truth emitter index (0 = false alarm)
%     txTime   truth transmit time (s)
%     mainbeam truth: pulse received within 10 dB of the mainbeam peak
%   pdw.habBias  per-HAB clock bias (s) drawn for this window (truth)

if nargin < 4, opts = struct(); end
if ~isfield(opts,'seed'),        opts.seed = scn.seed; end
if ~isfield(opts,'emitters'),    opts.emitters = 1:numel(scn.emitters); end
if ~isfield(opts,'habs'),        opts.habs = 1:numel(scn.habs); end
if ~isfield(opts,'falseAlarms'), opts.falseAlarms = true; end
pw.setSeed(opts.seed);

k  = pw.const();
rx = scn.rx;
nH = numel(scn.habs);
habBias = rx.sigmaSync_s*randn(nH,1);

C = {};   % cell of per-(emitter,hab) PDW blocks
for ie = opts.emitters(:).'
    em  = scn.emitters(ie);
    typ = scn.lib(em.typeIdx);
    [tx, f, azB, elB, azRel] = pulseTimes(em, typ, t0, dur);
    if isempty(tx), continue; end
    ch = pw.channelOf(f, rx);
    Pt_dBm = 10*log10(typ.Ppeak_W*1e3);

    for ih = opts.habs(:).'
        hab = scn.habs(ih);
        % horizon check at window center
        emMid = pw.emitterPosition(em, t0 + dur/2);
        if ~pw.isVisible(emMid, hab.lla), continue; end

        % optional pruning for ESA: keep dwells with any chance of detection
        idx = (1:numel(tx)).';
        if strcmp(typ.scanType,'esa')
            [azT, elT] = pw.aer(pw.emitterPosition(em, tx), repmat(hab.lla, numel(tx), 1));
            G = pw.txGain(typ, azB, elB, azT, elT, azRel);
            idx = find(G >= typ.G_dBi + typ.SLL_dB - 1 + 3);   % above sidelobe floor
            if isempty(idx)                                    % try sidelobes
                idx = (1:numel(tx)).';
            end
        end
        txi = tx(idx);
        emPos = pw.emitterPosition(em, txi);
        [azT, elT, R] = pw.aer(emPos, repmat(hab.lla, numel(txi), 1));
        if strcmp(typ.scanType,'esa')
            G = pw.txGain(typ, azB(idx), elB(idx), azT, elT, azRel(idx));
        else
            G = pw.txGain(typ, azB(idx), [], azT, elT);
        end
        chi = ch(idx);
        ok  = chi > 0;
        Prx = nan(size(txi));
        Prx(ok) = Pt_dBm + G(ok) + rx.Grx_dBi - pw.fspl(f(idx(ok)), R(ok)) ...
                  - rx.Lpol_dB - rx.Lfilt_dB;
        snr = nan(size(txi));
        snr(ok) = Prx(ok) - rx.noise_dBm(chi(ok)).';
        Pd  = zeros(size(txi));
        Pd(ok) = pw.pdFromSNR(snr(ok), rx.Pfa, 1);
        det = ok & (rand(size(txi)) < Pd);
        if ~any(det), continue; end

        snrLin = 10.^(snr(det)/10);
        rise   = 1./rx.Bvideo(chi(det)).';
        toa  = txi(det) + R(det)/k.c + habBias(ih) + rise./sqrt(snrLin).*randn(nnz(det),1);
        amp  = Prx(det) + rx.sigmaAmp_dB*randn(nnz(det),1);
        pwm  = typ.PW_s + 2*rise./sqrt(snrLin).*randn(nnz(det),1);
        mb   = G(det) >= typ.G_dBi - 10;
        n = nnz(det);
        C{end+1} = [ih*ones(n,1), toa, chi(det), pwm, amp, snr(det), ...
                    ie*ones(n,1), txi(det), mb]; %#ok<AGROW>
    end
end

% ---- false alarms: Poisson threshold crossings of receiver noise --------
if opts.falseAlarms
    for ih = opts.habs(:).'
        for c = 1:rx.nChannels
            lam = rx.Pfa*rx.Bvideo(c)*dur;
            n = poissrnd_(lam);
            if n == 0, continue; end
            toa = t0 + dur*rand(n,1);
            amp = rx.sens_dBm(c) + abs(randn(n,1));
            pwm = abs(1./rx.Bvideo(c)*(1 + randn(n,1)));
            C{end+1} = [ih*ones(n,1), toa, c*ones(n,1), pwm, amp, ...
                        rx.SNRreq_dB*ones(n,1), zeros(n,1), nan(n,1), zeros(n,1)]; %#ok<AGROW>
        end
    end
end

M = vertcat(C{:});
if isempty(M), M = zeros(0,9); end
M = sortrows(M, [1 2]);
pdw.hab = M(:,1); pdw.toa = M(:,2); pdw.ch = M(:,3); pdw.pw = M(:,4);
pdw.amp = M(:,5); pdw.snr = M(:,6); pdw.emitter = M(:,7);
pdw.txTime = M(:,8); pdw.mainbeam = logical(M(:,9));
pdw.habBias = habBias;
pdw.t0 = t0; pdw.dur = dur;
end

% -------------------------------------------------------------------------
function [tx, f, azB, elB, azRel] = pulseTimes(em, typ, t0, dur)
switch typ.scanType
    case 'rotating'
        pri = typ.PRI_s(:);
        frame = sum(pri);
        nFrames = ceil(dur/frame) + 1;
        kStart = floor(t0/frame);
        offs = [0; cumsum(pri(1:end-1))];
        tx = (kStart + (0:nFrames-1)) * frame;       % frame starts
        tx = bsxfun(@plus, offs, tx);
        tx = tx(:);
        tx = tx(tx >= t0 & tx < t0 + dur);
        [azB, elB, f] = pw.boresight(em, typ, tx);
        azRel = zeros(size(tx));
    case 'esa'
        dw = typ.esaDwell_s;
        k0 = floor((t0 + em.esaT0)/dw); k1 = floor((t0 + dur + em.esaT0)/dw);
        T = {};
        for kk = k0:k1
            ts = kk*dw - em.esaT0;
            [~, ~, ~, pri] = pw.boresight(em, typ, ts + dw/2);
            tp = ts + (0:floor(dw/pri)-1).'*pri;
            T{end+1} = tp; %#ok<AGROW>
        end
        tx = vertcat(T{:});
        tx = tx(tx >= t0 & tx < t0 + dur);
        [azB, elB, f, ~, info] = pw.boresight(em, typ, tx);
        azRel = info.azRel;
end
end

function n = poissrnd_(lam)
% Portable Poisson draw (Knuth for small lambda, normal approx for large).
if lam > 50
    n = max(0, round(lam + sqrt(lam)*randn));
    return
end
L = exp(-lam); n = 0; p = rand;
while p > L
    n = n + 1; p = p*rand;
end
end
