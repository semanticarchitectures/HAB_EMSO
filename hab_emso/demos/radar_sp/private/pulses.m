function s = pulses(t, PW, PRI, t0, A)
%PULSES Unmodulated baseband pulse train (random carrier phase per pulse).
s = zeros(size(t));
for tk = t0:PRI:t(end)
    m = t >= tk & t < tk + PW;
    s(m) = A*exp(1i*2*pi*rand);
end
end
