function [xyz, lla] = enu(llaRef, llaOrXyz, direction)
%PW.ENU Convert between geodetic and a local East-North-Up frame.
%   xyz = pw.enu(llaRef, lla)            geodetic N-by-3 -> ENU N-by-3 (m)
%   [~, lla] = pw.enu(llaRef, xyz, 'inverse')  ENU -> geodetic
%   The ENU frame is tangent to the spherical Earth at llaRef.
if nargin < 3, direction = 'forward'; end
lat = llaRef(1)*pi/180; lon = llaRef(2)*pi/180;
Rm = [-sin(lon)            cos(lon)           0;
      -sin(lat)*cos(lon)  -sin(lat)*sin(lon)  cos(lat);
       cos(lat)*cos(lon)   cos(lat)*sin(lon)  sin(lat)];
p0 = pw.lla2ecef(llaRef(:).');
if strcmpi(direction,'forward')
    d = pw.lla2ecef(llaOrXyz) - p0;
    xyz = d*Rm.';
    lla = llaOrXyz;
else
    p = llaOrXyz*Rm + p0;
    lla = pw.ecef2lla(p);
    xyz = llaOrXyz;
end
end
