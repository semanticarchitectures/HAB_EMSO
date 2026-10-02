function txt = callRemoteTool(cfg, name, d)
%CALLREMOTETOOL Call an MCP tool on the A2 server (MATLAB only).
persistent client
args = {d.nHAB, d.ringRadius_km, d.nChannels, d.sigmaSync_ns, d.dfOption, d.altBandHalf_km};
switch cfg.toolSource
    case 'prodserver'   % MCP Framework for MATLAB Production Server client utilities
        txt = prodserver.mcp.call(cfg.endpoint, name, args{:});
    case 'mcpclient'    % MATLAB MCP HTTP Client add-on (streamable HTTP servers)
        if isempty(client), client = mcpHTTPClient(cfg.endpoint); end
        txt = callTool(client, name, nHAB=d.nHAB, ringRadius_km=d.ringRadius_km, ...
            nChannels=d.nChannels, sigmaSync_ns=d.sigmaSync_ns, dfOption=d.dfOption, ...
            altBandHalf_km=d.altBandHalf_km);
    otherwise
        error('Unknown toolSource %s', cfg.toolSource);
end
end
