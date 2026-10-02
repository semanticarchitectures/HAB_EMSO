function report = evaluateHabDesign(nHAB, ringRadius_km, nChannels, sigmaSync_ns, dfOption, altBandHalf_km)
% Evaluate cost and performance of a balloon (HAB) EMSO constellation
% design over a 400 x 400 km littoral area with fixed-site, marine and
% airborne radar emitters. All costs and parameters are NOTIONAL.
%
%    report = evaluateHabDesign(nHAB, ringRadius_km, nChannels,
%        sigmaSync_ns, dfOption, altBandHalf_km) returns JSON with:
%        cost_USD           90-day campaign cost
%        effGeoCoverage     geolocation coverage x P(>= 3 balloons on station)
%        coverage.fixed / .marine / .airborne
%                           fraction of the area where the emitter class is
%                           geolocated to goal (1 km, 1 km, 25 km CEP50)
%        medianCEP_m        median CEP50 over geolocatable points
%        fracOnStation      single-balloon station-keeping fraction
%        payloadMass_kg, payloadPower_W, feasible (mass <= 4 kg, power <= 25 W)
%    Inputs:
%        nHAB            number of balloons, 3-8
%        ringRadius_km   station ring radius, 20-120 km
%        nChannels       filter-bank channels across 2-18 GHz: 8, 16, 32 or 64
%        sigmaSync_ns    inter-balloon clock error (1-sigma), 5-100 ns
%        dfOption        0 = filter bank only; 1 = add amplitude-comparison
%                        direction finding (needed for airborne ESA radars;
%                        roughly 4x the channel hardware)
%        altBandHalf_km  altitude-control authority, +- km around 20 km (3-4.5)
%
%  Example:
%    report = evaluateHabDesign(4, 45, 32, 30, 0, 4)

    arguments (Input)
        nHAB (1,1) double {mustBeInteger, mustBeInRange(nHAB, 3, 8)}              % number of balloons
        ringRadius_km (1,1) double {mustBeInRange(ringRadius_km, 20, 120)}        % ring radius, km
        nChannels (1,1) double {mustBeMember(nChannels, [8 16 32 64])}            % filter-bank channels
        sigmaSync_ns (1,1) double {mustBeInRange(sigmaSync_ns, 5, 100)}           % clock error, ns
        dfOption (1,1) double {mustBeMember(dfOption, [0 1])}                    % 1 = add DF
        altBandHalf_km (1,1) double {mustBeInRange(altBandHalf_km, 3, 4.5)}       % altitude band, +- km
    end
    arguments (Output)
        report (1,1) string   % JSON metrics
    end
    d = struct('nHAB', nHAB, 'ringRadius_km', ringRadius_km, 'nChannels', nChannels, ...
        'sigmaSync_ns', sigmaSync_ns, 'dfOption', dfOption, 'altBandHalf_km', altBandHalf_km);
    M = pw.evaluateDesign(d, struct('gridStep_km', 25));
    out = struct( ...
        'design', d, ...
        'cost_USD', round(M.cost_USD), ...
        'effGeoCoverage', round(M.effGeoCoverage, 3), ...
        'coverage', struct('fixed', round(M.perClass(1).coverGeo,3), ...
                           'marine', round(M.perClass(2).coverGeo,3), ...
                           'airborne', round(M.perClass(3).coverGeo,3)), ...
        'medianCEP_m', round(min(M.medianCEP_m, 1e6)), ...
        'fracOnStation', round(M.fracOnStation, 3), ...
        'pAtLeast3OnStation', round(M.pAtLeast3, 3), ...
        'payloadMass_kg', round(M.payloadMass_kg, 2), ...
        'payloadPower_W', round(M.payloadPower_W, 1), ...
        'feasible', logical(M.feasible), ...
        'note', "Notional seminar model; not real system data.");
    report = string(jsonencode(out));
end
