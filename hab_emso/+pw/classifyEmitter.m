function [id, score, ranked] = classifyEmitter(cl, lib, rx)
%PW.CLASSIFYEMITTER Match a deinterleaved cluster to the emitter library.
%   [id, score, ranked] = pw.classifyEmitter(cl, lib, rx)
%   Features available from a filter-bank detector:
%     frequency (channel edges only), pulse width, PRI set, scan type,
%     scan period, apparent beamwidth.
%   Each feature adds a Gaussian-like likelihood term; score is the mean
%   term in [0,1]. ranked is a table-like struct sorted by score.
%   NOTE: the library here is the scenario's own notional library; in
%   practice this is a curated parametric database, and ambiguity between
%   emitters sharing a channel/PW is expected and should be reported.
n = numel(lib);
s = zeros(n,1);
for i = 1:n
    L = lib(i);
    fIn = any(bsxfun(@eq, pw.channelOf(L.fAgile(:), rx), cl.channels(:).'), 2);
    terms = [];
    terms(end+1) = mean(fIn);                                  %#ok<AGROW>
    terms(end+1) = exp(-0.5*((cl.pw - L.PW_s)/(0.15*L.PW_s))^2); %#ok<AGROW>
    if ~isempty(cl.priSet)
        m = 0;
        for p = cl.priSet
            m = m + any(abs(L.PRI_s - p) < 0.02*p);
        end
        terms(end+1) = m/numel(cl.priSet);                   %#ok<AGROW>
    end
    sc = cl.scan;
    if strcmp(sc.scanType,'rotating')
        if strcmp(L.scanType,'rotating')
            terms(end+1) = exp(-0.5*((sc.period - L.scanPeriod_s)/(0.05*L.scanPeriod_s))^2); %#ok<AGROW>
        else
            terms(end+1) = 0;                                  %#ok<AGROW>
        end
    elseif any(strcmp(sc.scanType,{'raster','irregular'}))
        terms(end+1) = double(strcmp(L.scanType,'esa'))*0.8 + 0.2; %#ok<AGROW>
    end
    s(i) = mean(terms);
end
[ss, o] = sort(s, 'descend');
id = lib(o(1)).id; score = ss(1);
ranked.id = {lib(o).id}.'; ranked.score = ss;
end
