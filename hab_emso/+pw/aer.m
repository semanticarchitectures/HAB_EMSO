function [az, el, rng] = aer(llaFrom, llaTo)
%PW.AER Azimuth, elevation, slant range from one point to another.
%   [az, el, rng] = pw.aer(llaFrom, llaTo)
%     llaFrom  M-by-3 [lat lon alt] observer(s)
%     llaTo    N-by-3 targets (M==N, or one of them 1)
%     az       degrees clockwise from true north, [0,360)
%     el       degrees above the local horizontal (geometric, no refraction)
%     rng      slant range in meters
k = pw.const(); %#ok<NASGU>
p0 = pw.lla2ecef(llaFrom);
p1 = pw.lla2ecef(llaTo);
d  = p1 - p0;
lat = llaFrom(:,1)*pi/180; lon = llaFrom(:,2)*pi/180;
e = -sin(lon).*d(:,1) + cos(lon).*d(:,2);
n = -sin(lat).*cos(lon).*d(:,1) - sin(lat).*sin(lon).*d(:,2) + cos(lat).*d(:,3);
u =  cos(lat).*cos(lon).*d(:,1) + cos(lat).*sin(lon).*d(:,2) + sin(lat).*d(:,3);
az  = mod(atan2(e,n)*180/pi, 360);
el  = atan2(u, sqrt(e.^2+n.^2))*180/pi;
rng = sqrt(sum(d.^2,2));
end
