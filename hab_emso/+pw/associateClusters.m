function groups = associateClusters(C)
%PW.ASSOCIATECLUSTERS Link clusters from different HABs that are the same
%   emitter (same channel(s), PW and PRI signature; same scan period).
%   groups = pw.associateClusters(C)
%     C       cell array, C{h} = cluster array from pw.deinterleave for HAB h
%     groups  struct array: members (N-by-2 [hab clusterIdx]), channels,
%             pw, priSet, scanType, period
%   Greedy: seed with the richest unassigned cluster, then add at most one
%   compatible cluster per other HAB.
all = [];
for h = 1:numel(C)
    for k = 1:numel(C{h})
        all(end+1,:) = [h k C{h}(k).n]; %#ok<AGROW>
    end
end
groups = struct('members',{},'channels',{},'pw',{},'priSet',{},'scanType',{},'period',{});
if isempty(all), return; end
used = false(size(all,1),1);
[~, order] = sort(all(:,3), 'descend');
for s = order.'
    if used(s), continue; end
    A = C{all(s,1)}(all(s,2));
    mem = all(s,1:2); used(s) = true;
    for h = setdiff(1:numel(C), all(s,1))
        best = 0; bestScore = 0;
        for r = find(all(:,1) == h & ~used).'
            B = C{h}(all(r,2));
            sc = similarity(A, B);
            if sc > bestScore, best = r; bestScore = sc; end
        end
        if best > 0 && bestScore >= 0.7
            mem(end+1,:) = all(best,1:2); used(best) = true; %#ok<AGROW>
        end
    end
    g.members = mem; g.channels = A.channels; g.pw = A.pw; g.priSet = A.priSet;
    % group scan type: 'rotating' if >= 2 members independently see a
    % rotating beam (members outside the fan beam may see only sidelobes)
    types = arrayfun(@(r) C{mem(r,1)}(mem(r,2)).scan.scanType, 1:size(mem,1), 'UniformOutput', false);
    pers  = arrayfun(@(r) C{mem(r,1)}(mem(r,2)).scan.period,   1:size(mem,1));
    isRot = strcmp(types, 'rotating');
    if nnz(isRot) >= 2
        g.scanType = 'rotating'; g.period = median(pers(isRot));
    elseif any(strcmp(types,'raster'))
        g.scanType = 'raster'; g.period = median(pers(strcmp(types,'raster')));
    else
        g.scanType = A.scan.scanType; g.period = A.scan.period;
    end
    groups(end+1) = g; %#ok<AGROW>
end
end

function s = similarity(A, B)
s = 0;
if ~any(ismember(A.channels, B.channels)), return; end
if abs(A.pw - B.pw) > 0.2*max(A.pw, B.pw), return; end
t = [];
t(end+1) = numel(intersect(A.channels, B.channels))/numel(union(A.channels, B.channels));
t(end+1) = exp(-0.5*((A.pw - B.pw)/(0.08*A.pw))^2);
if ~isempty(A.priSet) && ~isempty(B.priSet)
    m = 0;
    for p = A.priSet, m = m + any(abs(B.priSet - p) < 0.01*p); end
    t(end+1) = m/numel(A.priSet);
end
if strcmp(A.scan.scanType,'rotating') && strcmp(B.scan.scanType,'rotating')
    t(end+1) = exp(-0.5*((A.scan.period - B.scan.period)/(0.02*A.scan.period))^2);
end
s = mean(t);
end
