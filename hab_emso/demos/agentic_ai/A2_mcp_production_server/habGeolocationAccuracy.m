function cep_m = habGeolocationAccuracy(emitterId, nHAB, ringRadius_km, emitterEast_km, emitterNorth_km, method)
% Predicted geolocation accuracy (CEP50, meters) of a ground or sea
% emitter by a ring of balloons, from a Cramer-Rao-type bound that
% accounts for which balloons can actually hear the emitter.
%
%    cep_m = habGeolocationAccuracy(emitterId, nHAB, ringRadius_km,
%        emitterEast_km, emitterNorth_km, method)
%        emitterId       emitter type from listEmitterTypes (rotating
%                        types support "scan"; "AIR-X1" needs "tdoa")
%        nHAB            number of balloons (3-12), evenly spaced on a ring
%        ringRadius_km   ring radius around the area-of-interest center, km
%        emitterEast_km, emitterNorth_km
%                        emitter position relative to the ring center, km
%        method          "scan"  - scan-timing (mainbeam sweep times)
%                        "tdoa"  - time difference of arrival (sidelobes)
%                        "both"  - hybrid of the two
%    Returns Inf when fewer than 3 balloons can use the emitter.
%
%  Example:
%    cep_m = habGeolocationAccuracy("FIX-S1", 4, 45, -140, -20, "both")

    arguments (Input)
        emitterId (1,1) string {mustBeMember(emitterId, ["FIX-S1","FIX-C1","MAR-X1","MAR-S1","AIR-X1"])}  % emitter type ID
        nHAB (1,1) double {mustBeInteger, mustBeInRange(nHAB, 3, 12)}         % number of balloons
        ringRadius_km (1,1) double {mustBeInRange(ringRadius_km, 10, 200)}   % ring radius, km
        emitterEast_km (1,1) double {mustBeInRange(emitterEast_km, -600, 600)}   % emitter east offset, km
        emitterNorth_km (1,1) double {mustBeInRange(emitterNorth_km, -600, 600)} % emitter north offset, km
        method (1,1) string {mustBeMember(method, ["scan","tdoa","both"])}   % measurement type
    end
    arguments (Output)
        cep_m (1,1) double   % CEP50 in meters (Inf if not observable)
    end
    origin = [36.0 -75.5 0];
    lib = pw.emitterLibrary(); rx = pw.defaultReceiver();
    typ = lib(strcmp({lib.id}, char(emitterId)));
    H = zeros(nHAB,3);
    for i = 1:nHAB
        ang = 45 + (i-1)*360/nHAB;
        [~, l] = pw.enu(origin, ringRadius_km*1e3*[sind(ang) cosd(ang) 0], 'inverse');
        H(i,:) = [l(1:2) 20e3];
    end
    [~, P] = pw.enu(origin, [emitterEast_km emitterNorth_km 0]*1e3, 'inverse');
    P(3) = typ.antHeight_m;
    [mOK, sOK] = pw.usableHABs(typ, P, H, rx);
    prm = struct('sigmaTDOA_s', sqrt(2)*rx.sigmaSync_s, 'sigmaAz_deg', 0.08);
    cS = inf; cT = inf;
    if any(method == ["scan","both"]) && strcmp(typ.scanType, 'rotating')
        prm.usable = mOK; cS = pw.geolocationCRLB(H, P, 'scan', prm);
    end
    if any(method == ["tdoa","both"])
        prm.usable = sOK; cT = pw.geolocationCRLB(H, P, 'tdoa', prm);
    end
    cep_m = round(1/sqrt(1/cS^2 + 1/cT^2));
end
