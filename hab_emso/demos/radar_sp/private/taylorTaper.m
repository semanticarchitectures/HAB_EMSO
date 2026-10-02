function w = taylorTaper(N, sll_dB, nbar)
%TAYLORTAPER Taylor amplitude taper (toolbox-free), column vector, peak 1.
%   Toolbox equivalent: taylorwin(N, nbar, -sll_dB).
if nargin < 3, nbar = 5; end
A = acosh(10^(sll_dB/20))/pi;
s2 = nbar^2/(A^2 + (nbar-0.5)^2);
x = ((0:N-1).' - (N-1)/2)/N;
w = ones(N,1);
for m = 1:nbar-1
    num = prod(1 - m^2/s2./(A^2 + ((1:nbar-1) - 0.5).^2));
    den = prod(1 - m^2./((1:nbar-1).^2).*((1:nbar-1) ~= m) );
    Fm = (-1)^(m+1)*num/(2*den);
    w = w + 2*Fm*cos(2*pi*m*x);
end
w = w/max(w);
end
