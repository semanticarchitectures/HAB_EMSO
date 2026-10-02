function report = listEmitterTypes()
% List the notional radar emitter types known to the HAB EMSO model.
%
%    report = listEmitterTypes() returns a JSON array. Each element has:
%        id           emitter type identifier to pass to other tools
%                     (e.g. "FIX-S1", "MAR-X1", "AIR-X1")
%        class        "fixed", "marine" or "airborne"
%        frequency_GHz, peakPower_kW, gain_dBi, pulseWidth_us, pri_us
%        scanType     "rotating" (mechanical) or "esa" (electronic)
%        scanPeriod_s rotation period or ESA frame time
%        description  one-line description
%    All values are NOTIONAL (seminar model), not real system data.
%
%  Example:
%    report = listEmitterTypes()

    arguments (Output)
        report (1,1) string   % JSON array describing each emitter type
    end
    lib = pw.emitterLibrary();
    s = struct('id', {lib.id}, 'class', {lib.class}, ...
        'frequency_GHz', num2cell([lib.fc]/1e9), ...
        'peakPower_kW', num2cell([lib.Ppeak_W]/1e3), ...
        'gain_dBi', num2cell([lib.G_dBi]), ...
        'pulseWidth_us', num2cell([lib.PW_s]*1e6), ...
        'pri_us', arrayfun(@(L) L.PRI_s*1e6, lib, 'UniformOutput', false), ...
        'scanType', {lib.scanType}, ...
        'scanPeriod_s', num2cell([lib.scanPeriod_s]), ...
        'description', {lib.description});
    report = string(jsonencode(s, PrettyPrint=true));
end
