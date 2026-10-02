function registerMcpToolPaths(habRoot)
%REGISTERMCPTOOLPATHS Put the HAB library and the MCP tool wrappers on the
%   MATLAB path in EVERY session, including sessions the MATLAB MCP Server
%   starts. Run once in MATLAB:
%       registerMcpToolPaths('/Users/you/hab_emso')
%   It appends two addpath lines to startup.m in your userpath folder
%   (idempotent: running it again does nothing). Custom MCP tools require
%   their functions to be on the MATLAB path; the server does not add them.
kitRoot = fileparts(mfilename('fullpath'));
toolDir = fullfile(kitRoot, 'mcp_tools');
if ~exist(fullfile(habRoot, '+pw'), 'dir')
    error('No +pw package under %s -- pass the hab_emso folder.', habRoot);
end
up = userpath;
if isempty(up), up = fullfile(getenv('HOME'), 'Documents', 'MATLAB'); end
up = strtok(up, pathsep);
if ~exist(up, 'dir'), mkdir(up); end
f = fullfile(up, 'startup.m');
txt = '';
if exist(f, 'file'), txt = fileread(f); end
lines = { '% --- HAB EMSO MCP tools (added by registerMcpToolPaths) ---', ...
          sprintf('addpath(''%s'', ''%s'', ''%s'');', habRoot, fullfile(habRoot,'tests'), toolDir) };
if contains(txt, lines{2})
    fprintf('startup.m already configured: %s\n', f);
else
    fid = fopen(f, 'a'); fprintf(fid, '\n%s\n%s\n', lines{:}); fclose(fid);
    fprintf('Added HAB tool paths to %s\n', f);
end
addpath(habRoot, fullfile(habRoot,'tests'), toolDir);
fprintf('Check: '); hab_intercept_range("MAR-X1", 20, "side");
end
