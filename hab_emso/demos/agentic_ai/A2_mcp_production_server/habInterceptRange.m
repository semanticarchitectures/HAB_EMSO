function range_km = habInterceptRange(emitterId, habAltitude_km, lobe)
% Maximum range at which a high-altitude balloon (HAB) with a notional
% Philowave-class filter-bank detector detects a radar emitter's pulses.
%
%    range_km = habInterceptRange(emitterId, habAltitude_km, lobe) returns
%        the one-way intercept range in km: the smaller of the link-budget
%        range and the radio horizon between the balloon and the emitter.
%        emitterId       emitter type from listEmitterTypes, e.g. "MAR-X1"
%        habAltitude_km  balloon float altitude in km (typically 15-25)
%        lobe            "main" (mainbeam illumination, used for scan-timing
%                        geolocation) or "side" (sidelobes; needed at 3+
%                        balloons simultaneously for TDOA geolocation)
%
%  Example:
%    range_km = habInterceptRange("MAR-X1", 20, "side") returns about 25 km.

    arguments (Input)
        emitterId (1,1) string {mustBeMember(emitterId, ["FIX-S1","FIX-C1","MAR-X1","MAR-S1","AIR-X1"])}  % emitter type ID
        habAltitude_km (1,1) double {mustBeInRange(habAltitude_km, 1, 40)}   % balloon altitude, km
        lobe (1,1) string {mustBeMember(lobe, ["main","side"])}              % "main" or "side"
    end
    arguments (Output)
        range_km (1,1) double   % intercept range in km
    end
    lib = pw.emitterLibrary();
    typ = lib(strcmp({lib.id}, char(emitterId)));
    rx = pw.defaultReceiver();
    R = pw.interceptRange(typ, rx, habAltitude_km*1e3, typ.antHeight_m, char(lobe));
    range_km = round(R/1e3, 1);
end
