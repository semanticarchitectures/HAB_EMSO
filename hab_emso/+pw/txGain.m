function G = txGain(typ, azB, elB, azT, elT, azRel)
%PW.TXGAIN Emitter antenna gain (dBi) toward a target direction.
%   G = pw.txGain(typ, azB, elB, azT, elT)          rotating fan beam
%   G = pw.txGain(typ, azB, elB, azT, elT, azRel)   ESA (azRel = scan angle)
%     azB, elB  boresight (deg); elB ignored for rotating fan beams
%     azT, elT  direction to the observer (deg) from the emitter
%
%   Pattern model (deliberately simple, analytic, vectorized):
%     mainbeam  Gaussian in dB: -12*(offset/BW)^2  (-3 dB at offset = BW/2)
%     sidelobes flat floor at SLL_dB below the mainbeam peak
%     fan beam  flat inside elCov_deg, Gaussian roll-off (2 deg) outside
%     ESA       2-D Gaussian around the steered beam, scan loss
%               15*log10(cos(scan angle)), back hemisphere at SLL-10 dB
d_az = mod(azT - azB + 180, 360) - 180;
switch typ.scanType
    case 'rotating'
        pAz = -12*(d_az/typ.azBW_deg).^2;
        lo = typ.elCov_deg(1); hi = typ.elCov_deg(2);
        out = max(lo - elT, 0) + max(elT - hi, 0);
        pEl = -12*(out/2).^2;
        G = typ.G_dBi + max(pAz + pEl, typ.SLL_dB);
    case 'esa'
        d_el = elT - elB;
        p = -12*((d_az/typ.azBW_deg).^2 + (d_el/typ.elCov_deg).^2);
        scanLoss = 15*log10(max(cosd(azRel), 0.05));
        G = typ.G_dBi + scanLoss + max(p, typ.SLL_dB - scanLoss);
        % observer behind the array face (relative to the platform heading)
        azHeading = mod(azB - azRel, 360);
        behind = abs(mod(azT - azHeading + 180, 360) - 180) > 90;
        G(behind) = typ.G_dBi + typ.SLL_dB - 10;
    otherwise
        error('pw:txGain', 'Unknown scanType');
end
end
