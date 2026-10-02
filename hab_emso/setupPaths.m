function setupPaths()
%SETUPPATHS Add the HAB/Philowave EMSO seminar library and demos to the path.
%   Run once per MATLAB session from any folder:  run('<root>/setupPaths.m')
root = fileparts(mfilename('fullpath'));
addpath(root);                                   % +pw package lives here
addpath(fullfile(root,'tests'));
d = dir(fullfile(root,'demos'));
for i = 1:numel(d)
    if d(i).isdir && d(i).name(1) ~= '.'
        addpath(fullfile(root,'demos',d(i).name));
    end
end
addpath(fullfile(root,'demos','agentic_ai','A1_agentic_toolkit'));
addpath(fullfile(root,'demos','agentic_ai','A1_agentic_toolkit','reference'));
addpath(fullfile(root,'demos','agentic_ai','A2_mcp_production_server'));
addpath(fullfile(root,'demos','agentic_ai','A3_mcp_client_multiagent'));
fprintf('HAB EMSO library ready (%s).\n', root);
fprintf('All emitter, receiver, balloon and cost parameters are NOTIONAL.\n');
end
