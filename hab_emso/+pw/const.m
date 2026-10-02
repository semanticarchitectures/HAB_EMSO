function k = const()
%PW.CONST Physical constants and modeling conventions used by the pw library.
%   k = pw.const() returns a struct with:
%     c      speed of light (m/s)
%     Re     spherical Earth radius (m)
%     kEff   effective-Earth-radius factor for radio line of sight (4/3)
%     kB     Boltzmann constant (J/K)
%     T0     reference noise temperature (K)
%
%   All geometry in this library uses a spherical Earth. That is adequate
%   for seminar-level EMSO analysis (errors of a few hundred meters in
%   absolute position, much less in relative geometry). Swap in WGS84
%   (Mapping Toolbox lla2ecef) for engineering-grade work.

k.c    = 299792458;
k.Re   = 6371000;
k.kEff = 4/3;
k.kB   = 1.380649e-23;
k.T0   = 290;
end
