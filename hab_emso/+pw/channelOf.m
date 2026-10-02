function ch = channelOf(f, rx)
%PW.CHANNELOF Filter-bank channel index for frequency f (Hz); 0 if outside.
e = rx.fEdges(:);
ch = interp1(e, (1:numel(e)).', f, 'previous');
ch(isnan(ch) | ch > rx.nChannels) = 0;
ch(f >= e(end) | f < e(1)) = 0;
ch = reshape(ch, size(f));
end
