function hab_identify_emitter(frequency_GHz, pulseWidth_us, pri_us_list, scanType, scanPeriod_s)
%HAB_IDENTIFY_EMITTER MCP custom tool: best library matches for PDW features.
%   pri_us_list is TEXT (custom tools accept no arrays): e.g. "950,980,1000".
scanType = char(scanType);
pri = str2num(['[' char(pri_us_list) ']']); %#ok<ST2NM>
if isempty(pri) || any(pri <= 0), disp(jsonencode(struct('error','pri_us_list must be numbers, e.g. "500" or "950,980,1000"'))); return; end
if ~any(strcmp(scanType, {'rotating','raster','irregular'})), disp(jsonencode(struct('error','scanType must be rotating, raster or irregular'))); return; end
rx = pw.defaultReceiver(); lib = pw.emitterLibrary();
cl.channels = pw.channelOf(frequency_GHz*1e9, rx);
if cl.channels == 0, disp(jsonencode(struct('error','frequency outside the 2-18 GHz filter bank'))); return; end
cl.pw = pulseWidth_us*1e-6; cl.priSet = pri(:).'*1e-6;
cl.scan = struct('scanType', scanType, 'period', scanPeriod_s);
if scanPeriod_s <= 0, cl.scan.period = NaN; end
[~, ~, r] = pw.classifyEmitter(cl, lib, rx);
top = struct('id', r.id(1:3), 'score', num2cell(round(100*r.score(1:3))/100));
disp(jsonencode(struct('channel', cl.channels, 'matches', top)));
end
