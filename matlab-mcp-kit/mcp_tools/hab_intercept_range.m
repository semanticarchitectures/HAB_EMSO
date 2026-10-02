function hab_intercept_range(emitterId, altitude_km, lobe)
%HAB_INTERCEPT_RANGE MCP custom tool: balloon intercept range of an emitter (km).
emitterId = char(emitterId); lobe = char(lobe);
lib = pw.emitterLibrary();
i = find(strcmp({lib.id}, emitterId), 1);
if isempty(i), fail(sprintf('Unknown emitterId "%s". Valid: %s', emitterId, strjoin({lib.id}, ', '))); return; end
if ~any(strcmp(lobe, {'main','side'})), fail('lobe must be "main" or "side"'); return; end
if ~(altitude_km >= 1 && altitude_km <= 40), fail('altitude_km must be 1-40'); return; end
[R, info] = pw.interceptRange(lib(i), pw.defaultReceiver(), altitude_km*1e3, lib(i).antHeight_m, lobe);
disp(jsonencode(struct('emitterId', emitterId, 'lobe', lobe, 'altitude_km', altitude_km, ...
    'range_km', round(R/1e2)/10, 'linkLimited_km', round(info.Rlink/1e2)/10, ...
    'horizon_km', round(info.Rhorizon/1e2)/10)));
end

function fail(msg)
disp(jsonencode(struct('error', msg)));
end
