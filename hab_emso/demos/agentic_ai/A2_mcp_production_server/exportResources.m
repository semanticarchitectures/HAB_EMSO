function files = exportResources()
%EXPORTRESOURCES Write the MCP resources (read-only reference data) that the
%   HAB EMSO server exposes alongside its tools, so an LLM can read real
%   (notional) parameter values instead of guessing them.
here = fileparts(mfilename('fullpath'));
out = fullfile(here, 'resources');
if ~exist(out, 'dir'), mkdir(out); end
lib = pw.emitterLibrary();
rx  = pw.defaultReceiver();
em = rmfield(lib, {'esaAz_deg'});
for i = 1:numel(em)
    em(i).fc = em(i).fc/1e9; em(i).fAgile = em(i).fAgile/1e9;
    em(i).PW_s = em(i).PW_s*1e6; em(i).PRI_s = em(i).PRI_s*1e6;
end
em = renameField(em, {'fc','fAgile','PW_s','PRI_s'}, {'fc_GHz','fAgile_GHz','PW_us','PRI_us'});
files{1} = fullfile(out, 'emitter_library.json');
writeJSON(files{1}, struct('note', 'NOTIONAL seminar emitter library', 'emitters', em));
r = struct('note', 'NOTIONAL Philowave-class filter-bank detector (not vendor data)', ...
    'band_GHz', [rx.fEdges(1) rx.fEdges(end)]/1e9, 'nChannels', rx.nChannels, ...
    'channelWidth_MHz', rx.B(1)/1e6, 'noiseFigure_dB', rx.NF_dB, ...
    'sensitivity_dBm', rx.sens_dBm(1), 'Pfa', rx.Pfa, 'Pd', rx.Pd, ...
    'clockSigma_ns', rx.sigmaSync_s*1e9, 'power_W', rx.power_W, 'mass_kg', rx.mass_kg, ...
    'measures', {{'channel','time of arrival','pulse width','amplitude'}}, ...
    'doesNotMeasure', {{'phase','fine frequency','angle of arrival (without DF option)'}});
files{2} = fullfile(out, 'receiver_notional.json');
writeJSON(files{2}, r);
fprintf('Wrote %s\n', files{:});
end

function s = renameField(s, old, new)
for k = 1:numel(old)
    [s.(new{k})] = s.(old{k});
    s = rmfield(s, old{k});
end
end

function writeJSON(f, s)
fid = fopen(f, 'w'); fprintf(fid, '%s', jsonencode(s, PrettyPrint=true)); fclose(fid);
end
