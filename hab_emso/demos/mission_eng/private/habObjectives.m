function f = habObjectives(x, bandGrid, fracGrid)
%HABOBJECTIVES [cost $M, -effective coverage, median CEP km] for design x.
xr = roundDesign(x);
d = struct('nHAB', xr(1), 'ringRadius_km', xr(2), 'nChannels', xr(3), ...
    'sigmaSync_ns', xr(4), 'dfOption', xr(5), 'altBandHalf_km', xr(6));
o = struct('gridStep_km', 25, 'stationFrac', interp1(bandGrid, fracGrid, xr(6)));
M = pw.evaluateDesign(d, o);
f = [M.cost_USD/1e6, -M.effGeoCoverage, min(M.medianCEP_m, 50e3)/1e3];
end
