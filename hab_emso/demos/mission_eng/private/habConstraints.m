function [c, ceq] = habConstraints(x)
%HABCONSTRAINTS Payload SWaP limits (notional): mass <= 4 kg, power <= 25 W.
xr = roundDesign(x);
rx = pw.defaultReceiver(xr(3));
df = xr(5);
syncMass = interp1([5 10 30 100], [0.6 0.3 0 0], min(max(xr(4),5),100));
mass  = rx.mass_kg + syncMass + df*(3*(rx.mass_kg - 0.8) + 0.4);
power = rx.power_W + 2*(xr(4) < 20) + df*3*(rx.power_W - 4.0);
c = [mass - 4.0, power - 25];
ceq = [];
end
