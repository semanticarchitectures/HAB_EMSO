function [video, tv, info] = rfFrontEnd(x, fs, rx, chans, opts)
%PW.RFFRONTEND Signal-level model of the filter-bank + envelope detector.
%   [video, tv, info] = pw.rfFrontEnd(x, fs, rx)
%   [video, tv, info] = pw.rfFrontEnd(x, fs, rx, chans, opts)
%     x      real RF samples (V) at sample rate fs (must exceed 2*18 GHz for
%            the full band; the demos use 40 GS/s over tens of microseconds)
%     chans  channel indices to compute (default: all)
%     opts.skirt      filter transition width as a fraction of B (0.1)
%     opts.decimate   output decimation factor (default fs/(4*max Bvideo))
%   video  numel(tv)-by-numel(chans) detector output (W into 1 ohm, i.e.
%          lowpass-filtered x_filtered^2), noise-referred
%   info.decimate  decimation factor used; info.L video filter lengths (samples)
%
%   Chain per channel: bandpass (raised-cosine edges, frequency domain) ->
%   square-law detector -> video lowpass (moving average of 1/Bvideo).
%   No phase or fine frequency survives this chain -- which is exactly the
%   SWaP advantage and the information limit of the architecture.
if nargin < 4 || isempty(chans), chans = 1:rx.nChannels; end
if nargin < 5, opts = struct(); end
if ~isfield(opts,'skirt'), opts.skirt = 0.1; end
x = x(:); Nx = numel(x);
if ~isfield(opts,'decimate'), opts.decimate = max(1, floor(fs/(4*max(rx.Bvideo(chans))))); end
X = fft(x);
f = (0:Nx-1).'*fs/Nx; f(f > fs/2) = f(f > fs/2) - fs; af = abs(f);
dec = opts.decimate;
tv = ((0:dec:Nx-1)/fs).';
video = zeros(numel(tv), numel(chans));
info.decimate = opts.decimate; info.L = zeros(1,numel(chans));
for q = 1:numel(chans)
    c = chans(q);
    lo = rx.fEdges(c); hi = rx.fEdges(c+1); w = opts.skirt*(hi-lo);
    H = rc(af, lo, w) .* (1 - rc(af, hi, w));
    y = real(ifft(X.*H));
    s = y.^2;
    L = max(1, round(fs/rx.Bvideo(c))); info.L(q) = L;
    v = filter(ones(L,1)/L, 1, s);
    video(:,q) = v(1:dec:end);
end
end

function g = rc(f, f0, w)
% raised-cosine step: 0 below f0-w/2, 1 above f0+w/2
g = zeros(size(f));
g(f >= f0 + w/2) = 1;
m = abs(f - f0) < w/2;
g(m) = 0.5*(1 + sin(pi*(f(m)-f0)/w));
end
