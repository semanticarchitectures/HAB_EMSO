function hab_geolocation_accuracy(emitterId, nHAB, ringRadius_km, east_km, north_km, method)
%HAB_GEOLOCATION_ACCURACY MCP custom tool: predicted CEP50 (m) for an emitter
%   at (east_km, north_km) from the AOI center, seen by nHAB balloons on a ring.
emitterId = char(emitterId); method = char(method);
lib = pw.emitterLibrary(); rx = pw.defaultReceiver();
i = find(strcmp({lib.id}, emitterId), 1);
if isempty(i), disp(jsonencode(struct('error', ['Unknown emitterId ' emitterId]))); return; end
if nHAB < 3 || nHAB > 12 || nHAB ~= round(nHAB), disp(jsonencode(struct('error','nHAB must be an integer 3-12'))); return; end
if ~any(strcmp(method, {'scan','tdoa','both'})), disp(jsonencode(struct('error','method must be scan, tdoa or both'))); return; end
typ = lib(i); origin = [36.0 -75.5 0];
H = zeros(nHAB,3);
for k = 1:nHAB
    ang = 45 + (k-1)*360/nHAB;
    [~, l] = pw.enu(origin, ringRadius_km*1e3*[sind(ang) cosd(ang) 0], 'inverse');
    H(k,:) = [l(1:2) 20e3];
end
[~, P] = pw.enu(origin, [east_km north_km 0]*1e3, 'inverse'); P(3) = typ.antHeight_m;
[mOK, sOK] = pw.usableHABs(typ, P, H, rx);
prm = struct('sigmaTDOA_s', sqrt(2)*rx.sigmaSync_s, 'sigmaAz_deg', 0.08);
cS = inf; cT = inf;
if any(strcmp(method, {'scan','both'})) && strcmp(typ.scanType, 'rotating')
    prm.usable = mOK; cS = pw.geolocationCRLB(H, P, 'scan', prm);
end
if any(strcmp(method, {'tdoa','both'}))
    prm.usable = sOK; cT = pw.geolocationCRLB(H, P, 'tdoa', prm);
end
cep = 1/sqrt(1/cS^2 + 1/cT^2);
out = struct('emitterId', emitterId, 'method', method, 'cep50_m', round(cep), ...
    'habsHearingMainbeam', nnz(mOK), 'habsHearingSidelobes', nnz(sOK), ...
    'observable', isfinite(cep));
if ~isfinite(cep), out.cep50_m = -1; end
disp(jsonencode(out));
end
