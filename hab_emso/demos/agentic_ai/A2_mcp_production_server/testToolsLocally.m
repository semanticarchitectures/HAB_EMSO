%% testToolsLocally - Call every MCP tool function directly in MATLAB
% Run this BEFORE building: the MCP framework assumes your functions are
% already correct. Uses matlab.unittest-style checks via assert.
setupPaths;
r = listEmitterTypes();                       disp(extractBefore(r, 200));
R = habInterceptRange("MAR-X1", 20, "side");  fprintf('MAR-X1 sidelobe range: %.1f km\n', R);
assert(R > 15 && R < 40);
assert(habInterceptRange("FIX-S1", 20, "main") <= 600);
c1 = habGeolocationAccuracy("FIX-S1", 4, 45, -140, -20, "both");
c2 = habGeolocationAccuracy("FIX-S1", 4, 45,   10,  10, "both");
fprintf('FIX-S1 CEP outside ring %.0f m, inside ring %.0f m\n', c1, c2);
assert(c2 < c1);
assert(isinf(habGeolocationAccuracy("AIR-X1", 4, 45, 0, 100, "tdoa")));
j = jsondecode(evaluateHabDesign(4, 45, 32, 30, 0, 4));
fprintf('baseline design: $%.2fM, effective coverage %.2f\n', j.cost_USD/1e6, j.effGeoCoverage);
assert(j.coverage.airborne < 0.05);
k = jsondecode(identifyEmitter(9.4, 0.5, 500, "rotating", 2.5));
fprintf('identify 9.4 GHz / 0.5 us / 500 us / 2.5 s -> %s (%.2f)\n', k.matches(1).id, k.matches(1).score);
assert(strcmp(k.matches(1).id, 'MAR-X1'));
try
    habInterceptRange("NOT-A-RADAR", 20, "main"); error('should have failed');
catch err
    fprintf('Invalid input rejected by the arguments block: %s\n', err.identifier);
end
disp('All tool functions OK.');
