function [d, why, nTools] = offlinePlanner(r, log)
%OFFLINEPLANNER Scripted stand-in for the planner LLM (no network needed).
%   Applies simple engineering rules to the previous round's MATLAB-verified
%   failures -- the kind of reasoning the LLM planner is asked to do.
nTools = 0;
if r == 1
    d = struct('nHAB', 4, 'ringRadius_km', 45, 'nChannels', 32, 'sigmaSync_ns', 30, ...
               'dfOption', 0, 'altBandHalf_km', 3);
    why = 'Start from the baseline: 4 balloons on a 45 km ring, 32 channels, no DF.';
    return
end
d = log(end).design; f = strjoin(log(end).failures, ' | '); m = log(end).metrics;
why = {};
if ~isempty(strfind(f, 'station keeping')) && d.altBandHalf_km < 4
    d.altBandHalf_km = 4; why{end+1} = 'widen the altitude band to +-4 km (station keeping)';
end
if ~isempty(strfind(f, 'airborne')) && d.dfOption == 0
    d.dfOption = 1; d.nChannels = 16;
    why{end+1} = 'add amplitude-comparison DF for the ESA radar and drop to 16 channels to stay within SWaP';
end
if ~isempty(strfind(f, 'SWaP')) && d.nChannels > 8
    d.nChannels = d.nChannels/2; why{end+1} = 'halve the channel count to meet SWaP';
end
if ~isempty(strfind(f, 'marine')) || ~isempty(strfind(f, 'airborne coverage'))
    if d.ringRadius_km < 80
        d.ringRadius_km = 80; why{end+1} = 'widen the ring to 80 km to spread balloons over the sea lanes';
    elseif d.nHAB < 8
        d.nHAB = d.nHAB + 2; why{end+1} = 'add two balloons for coverage and resilience';
    end
end
if ~isempty(strfind(f, 'cost')) && d.sigmaSync_ns < 100
    d.sigmaSync_ns = 100; why{end+1} = 'relax clocks to 100 ns (scan timing carries the rotating emitters)';
end
if isempty(why)
    d.nHAB = min(d.nHAB + 1, 8); why{end+1} = 'add one balloon';
end
why = strjoin(why, '; ');
end
