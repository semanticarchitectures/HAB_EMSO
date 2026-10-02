function toa = formPulses(det, t, mergeGap)
%FORMPULSES Leading-edge times of threshold-crossing runs; runs separated by
%   fewer than mergeGap samples are merged into one pulse.
idx = find(det);
if isempty(idx), toa = zeros(0,1); return; end
starts = idx([true; diff(idx) > mergeGap]);
toa = t(starts);
end
