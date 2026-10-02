function [tf, dGround, dHorizon] = isVisible(llaA, llaB)
%PW.ISVISIBLE Radio line of sight over a smooth 4/3-Earth.
%   [tf, dGround, dHorizon] = pw.isVisible(llaA, llaB)
%   tf is true when the great-circle ground distance is less than the sum
%   of the two radio horizons sqrt(2*k*Re*h). Terrain masking is not
%   modeled here; see demos/emso/D3 for a terrain-aware extension.
k = pw.const();
dGround = pw.groundRange(llaA, llaB);
hA = max(llaA(:,3),0); hB = max(llaB(:,3),0);
dHorizon = sqrt(2*k.kEff*k.Re*hA) + sqrt(2*k.kEff*k.Re*hB);
tf = dGround <= dHorizon;
end
