function xr = roundDesign(x)
%ROUNDDESIGN Map a continuous GA vector to a realizable design vector.
%   [nHAB ring nCh sync DF band] with integer nHAB, nCh in {8,16,32,64}, DF in {0,1}
ch = [8 16 32 64];
[~, ic] = min(abs(log2(ch) - log2(x(3))));
xr = [round(x(1)), x(2), ch(ic), x(4), double(x(5) >= 0.5), x(6)];
end
