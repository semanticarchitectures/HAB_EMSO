function p = lla2ecef(lla)
%PW.LLA2ECEF Geodetic [lat lon alt] (deg, deg, m) to Earth-centered XYZ (m).
%   p = pw.lla2ecef(lla) accepts an N-by-3 array and returns N-by-3.
%   Spherical Earth (see pw.const).
k = pw.const();
lat = lla(:,1)*pi/180; lon = lla(:,2)*pi/180; r = k.Re + lla(:,3);
p = [r.*cos(lat).*cos(lon), r.*cos(lat).*sin(lon), r.*sin(lat)];
end
