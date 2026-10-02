function lla = ecef2lla(p)
%PW.ECEF2LLA Earth-centered XYZ (m) to [lat lon alt] (deg, deg, m). N-by-3.
k = pw.const();
r = sqrt(sum(p.^2,2));
lat = asin(p(:,3)./r)*180/pi;
lon = atan2(p(:,2),p(:,1))*180/pi;
lla = [lat, lon, r - k.Re];
end
