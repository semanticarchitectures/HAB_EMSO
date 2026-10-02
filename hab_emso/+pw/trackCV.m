function trk = trackCV(t, xy, Rk, q)
%PW.TRACKCV Constant-velocity Kalman filter on 2-D position fixes.
%   trk = pw.trackCV(t, xy, Rk, q)
%     t    K-by-1 fix times (s), increasing
%     xy   K-by-2 fixes in a local ENU frame (m)
%     Rk   2-by-2-by-K fix covariances (m^2), e.g. sol.covENU(1:2,1:2)
%     q    process noise PSD (m^2/s^3); ~0.05 for ships, ~5 for aircraft
%   trk.x  K-by-4 [e n ve vn] filtered states; trk.P 4-by-4-by-K
%   Toolbox alternative: trackerGNN / trackerJPDA with initcvekf
%   (Sensor Fusion and Tracking Toolbox) -- see demos/emso/D3.
K = numel(t);
x = [xy(1,:) 0 0].';
P = blkdiag(Rk(:,:,1), 20^2*eye(2));
trk.x = zeros(K,4); trk.P = zeros(4,4,K);
trk.x(1,:) = x.'; trk.P(:,:,1) = P;
H = [eye(2) zeros(2)];
for kk = 2:K
    dt = t(kk) - t(kk-1);
    F = [eye(2) dt*eye(2); zeros(2) eye(2)];
    Q = q*[dt^3/3*eye(2) dt^2/2*eye(2); dt^2/2*eye(2) dt*eye(2)];
    x = F*x; P = F*P*F.' + Q;
    S = H*P*H.' + Rk(:,:,kk);
    Kg = P*H.'/S;
    x = x + Kg*(xy(kk,:).' - H*x);
    P = (eye(4) - Kg*H)*P;
    trk.x(kk,:) = x.'; trk.P(:,:,kk) = P;
end
end
