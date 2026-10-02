function f = makeSampleData()
%MAKESAMPLEDATA Write pdw_sample.csv: 32 s of recorded intercepts at one
%   balloon (HAB-1), the "live data" the agent analyzes in prompt 5.
%   Columns: toa_s, channel, pw_us, amp_dBm  (no truth columns -- the agent
%   must work it out). Truth is written separately to pdw_sample_truth.csv
%   for the presenter.
here = fileparts(mfilename('fullpath'));
scn = pw.defaultScenario();
pdw = pw.generatePDWs(scn, 0, 32, struct('habs', 1, 'seed', 2026));
f = fullfile(here, 'pdw_sample.csv');
fid = fopen(f, 'w');
fprintf(fid, 'toa_s,channel,pw_us,amp_dBm\n');
fprintf(fid, '%.9f,%d,%.4f,%.2f\n', [pdw.toa pdw.ch pdw.pw*1e6 pdw.amp].');
fclose(fid);
ft = fullfile(here, 'pdw_sample_truth.csv');
fid = fopen(ft, 'w');
fprintf(fid, 'toa_s,emitter\n');
names = [{'false_alarm'} {scn.emitters.id}];
for i = 1:numel(pdw.toa)
    fprintf(fid, '%.9f,%s\n', pdw.toa(i), names{pdw.emitter(i)+1});
end
fclose(fid);
fprintf('Wrote %s (%d PDWs) and truth file.\n', f, numel(pdw.toa));
end
