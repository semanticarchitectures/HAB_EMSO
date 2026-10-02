function y = bandlimit(x, fs, B)
%BANDLIMIT Ideal brick-wall channel filter, +-B/2 around complex baseband.
N = numel(x); f = (0:N-1).'*fs/N; f(f >= fs/2) = f(f >= fs/2) - fs;
X = fft(x); X(abs(f) > B/2) = 0; y = ifft(X);
end
