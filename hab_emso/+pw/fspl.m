function L = fspl(f, R)
%PW.FSPL One-way free-space path loss in dB. f in Hz, R in meters.
k = pw.const();
lambda = k.c ./ f;
L = 20*log10(4*pi*R./lambda);
end
