function [pred, sig, isAng] = predictMeas(meas, habLLA, P, dirs)
%PW.PREDICTMEAS Predicted measurements for candidate emitter positions.
%   [pred, sig, isAng] = pw.predictMeas(meas, habLLA, P, dirs)
%     meas    struct array (see pw.buildMeasurements)
%     habLLA  nHAB-by-3 HAB positions
%     P       N-by-3 candidate emitter positions [lat lon alt]
%     dirs    rotation direction (+1/-1) assumed for each 'scan' meas
%   pred   N-by-M predictions (s for 'tdoa'; deg for 'scan')
%   sig    1-by-M measurement sigmas in the same units
%   isAng  1-by-M true for angular (scan-timing) measurements
k = pw.const();
N = size(P,1); M = numel(meas);
pred = zeros(N,M); sig = zeros(1,M); isAng = false(1,M);
pE = pw.lla2ecef(P);
hE = pw.lla2ecef(habLLA);
for m = 1:M
    i = meas(m).i; j = meas(m).j;
    switch meas(m).type
        case 'tdoa'
            ri = sqrt(sum(bsxfun(@minus, pE, hE(i,:)).^2, 2));
            rj = sqrt(sum(bsxfun(@minus, pE, hE(j,:)).^2, 2));
            pred(:,m) = (rj - ri)/k.c;
            sig(m) = meas(m).sigma;
        case 'scan'
            azi = pw.aer(P, repmat(habLLA(i,:), N, 1));
            azj = pw.aer(P, repmat(habLLA(j,:), N, 1));
            pred(:,m) = mod(dirs(m)*(azj - azi), 360);
            sig(m) = 360*meas(m).sigma/meas(m).period;
            isAng(m) = true;
    end
end
end
