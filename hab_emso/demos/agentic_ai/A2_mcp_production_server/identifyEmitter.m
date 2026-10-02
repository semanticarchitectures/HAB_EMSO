function report = identifyEmitter(frequency_GHz, pulseWidth_us, pri_us, scanType, scanPeriod_s)
% Identify a radar emitter from the features a filter-bank detector can
% measure, against the notional emitter library (see listEmitterTypes).
%
%    report = identifyEmitter(frequency_GHz, pulseWidth_us, pri_us,
%        scanType, scanPeriod_s) returns JSON with the three best matches
%        (id, score 0-1) and the filter-bank channel the frequency falls in.
%        frequency_GHz  carrier (only the 500 MHz channel is used, as the
%                       detector cannot measure fine frequency), 2-18 GHz
%        pulseWidth_us  pulse width, microseconds
%        pri_us         pulse repetition interval(s), microseconds; a vector
%                       for staggered PRI, e.g. [950 980 1000 1020 1050]
%        scanType       "rotating", "raster" (electronic, periodic) or "irregular"
%        scanPeriod_s   scan/rotation period in seconds (0 if unknown)
%
%  Example:
%    report = identifyEmitter(9.4, 0.5, 500, "rotating", 2.5)

    arguments (Input)
        frequency_GHz (1,1) double {mustBeInRange(frequency_GHz, 2, 18)}   % carrier, GHz
        pulseWidth_us (1,1) double {mustBePositive}                        % pulse width, us
        pri_us (1,:) double {mustBePositive}                               % PRI(s), us
        scanType (1,1) string {mustBeMember(scanType, ["rotating","raster","irregular"])} % scan type
        scanPeriod_s (1,1) double {mustBeNonnegative}                      % scan period, s
    end
    arguments (Output)
        report (1,1) string   % JSON: best matches and channel
    end
    rx = pw.defaultReceiver(); lib = pw.emitterLibrary();
    cl.channels = pw.channelOf(frequency_GHz*1e9, rx);
    cl.pw = pulseWidth_us*1e-6;
    cl.priSet = pri_us*1e-6;
    cl.scan = struct('scanType', char(scanType), 'period', scanPeriod_s);
    if scanPeriod_s == 0, cl.scan.period = NaN; end
    [~, ~, ranked] = pw.classifyEmitter(cl, lib, rx);
    top = struct('id', ranked.id(1:3), 'score', num2cell(round(ranked.score(1:3), 2)));
    out = struct('channel', cl.channels, ...
        'channelEdges_GHz', rx.fEdges(cl.channels + [0 1])/1e9, 'matches', top);
    report = string(jsonencode(out));
end
