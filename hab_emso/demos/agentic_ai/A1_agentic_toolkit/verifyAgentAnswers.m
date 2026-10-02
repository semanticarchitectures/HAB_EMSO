%% verifyAgentAnswers - Presenter's ground truth for the A1 live demo
% Run after each prompt to check what the agent reported. The agent's job
% is judged against these tested library results, not against its own
% confidence.
setupPaths;
fprintf('--- Prompt 2/3: intercept ranges ---\n');
run(fullfile(fileparts(mfilename('fullpath')), 'reference', 'habLinkBudgetStudy.m'));
fprintf('\n--- Prompt 5: emitters in pdw_sample.csv (truth) ---\n');
here = fileparts(mfilename('fullpath'));
f = fullfile(here, 'pdw_sample_truth.csv');
if ~exist(f, 'file'), makeSampleData(); end
T = readtable(f, 'TextType', 'string');
[g, id] = findgroups(T.emitter);
n = splitapply(@numel, T.toa_s, g);
disp(table(id, n, 'VariableNames', {'emitter','PDWs'}));
lib = pw.emitterLibrary();
disp(table(string({lib.id}).', [lib.scanPeriod_s].', 'VariableNames', {'emitter','scanPeriod_s'}));
