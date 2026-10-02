function res = runChain(scn, t0)
%RUNCHAIN Sense -> understand -> geolocate for all emitters (32 s window).
rx = scn.rx; nH = numel(scn.habs); habLLA = vertcat(scn.habs.lla);
pdw = pw.generatePDWs(scn, t0, 32, struct('seed', 7 + round(t0)));
C = cell(1,nH);
for h = 1:nH, C{h} = pw.deinterleave(pdw, h, struct('rx', rx)); end
G = pw.associateClusters(C);
res = struct('ie',{},'id',{},'sol',{},'err',{},'info',{});
for g = 1:numel(G)
    m = G(g).members; c1 = C{m(1,1)}(m(1,2));
    if c1.truth == 0, continue; end
    id = pw.classifyEmitter(c1, scn.lib, rx);
    ie = find(strcmp({scn.emitters.id}, id), 1);
    em = scn.emitters(ie); typ = scn.lib(em.typeIdx);
    alt = em.lla0(3); if strcmp(typ.class,'airborne'), alt = NaN; end
    [sol, ~, info] = pw.locateGroup(pdw, G(g), C, habLLA, rx, alt);
    e = NaN;
    if ~isempty(sol), e = pw.groundRange(sol.lla, pw.emitterPosition(em, t0 + 16)); end
    res(end+1) = struct('ie',ie,'id',id,'sol',sol,'err',e,'info',info); %#ok<AGROW>
end
end
