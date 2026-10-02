function d = groundRange(llaA, llaB)
%PW.GROUNDRANGE Great-circle distance (m) between sub-points (haversine).
k = pw.const();
la1 = llaA(:,1)*pi/180; la2 = llaB(:,1)*pi/180;
dla = la2 - la1; dlo = (llaB(:,2)-llaA(:,2))*pi/180;
a = sin(dla/2).^2 + cos(la1).*cos(la2).*sin(dlo/2).^2;
d = 2*k.Re*asin(min(1,sqrt(a)));
end
