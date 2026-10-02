function lib = emitterLibrary()
%PW.EMITTERLIBRARY Notional parametric library of scanning radar emitters.
%   lib = pw.emitterLibrary() returns a struct array, one entry per emitter
%   TYPE. Three classes are modeled, as requested for the seminar series:
%
%     FIXED    land-based sites, mechanically ROTATING antennas
%     MARINE   shipborne, mechanically ROTATING antennas
%     AIRBORNE fighter-class fire-control radar, ELECTRONICALLY SCANNED
%              (AESA raster, frequency agile, low sidelobes)
%
%   *** ALL VALUES ARE NOTIONAL and representative of generic classes;
%   they do not describe any specific fielded system. ***
%
%   Fields
%     id, class, description
%     fc            nominal carrier (Hz)
%     fAgile        list of carriers used (Hz); one per dwell for ESA
%     Ppeak_W       peak transmit power
%     G_dBi         mainbeam gain
%     azBW_deg      3-dB azimuth beamwidth
%     elCov_deg     [lo hi] elevation coverage of the fan beam (rotating),
%                   or 3-dB elevation beamwidth for ESA (scalar)
%     SLL_dB        average sidelobe level relative to mainbeam (negative)
%     PW_s          pulse width
%     PRI_s         PRI sequence (stagger repeats); ESA uses one PRI per dwell
%     scanType      'rotating' | 'esa'
%     scanPeriod_s  rotation period (rotating); frame time (esa, derived)
%     rotDir        +1 clockwise, -1 counter-clockwise (rotating)
%     scanJitter    1-sigma fractional rotation-rate variation per scan
%     esaAz_deg     azimuth beam positions relative to heading (esa)
%     esaEl_deg     elevation bars (esa)
%     esaDwell_s    dwell per beam position (esa)
%     antHeight_m   antenna height above the platform reference

L = struct([]);

% ---------------- FIXED SITES (rotating) ---------------------------------
e = base();
e.id = 'FIX-S1'; e.class = 'fixed';
e.description = 'S-band long-range air surveillance, rotating, staggered PRI';
e.fc = 2.95e9; e.fAgile = e.fc;
e.Ppeak_W = 500e3; e.G_dBi = 34; e.azBW_deg = 1.4; e.elCov_deg = [0 30];
e.SLL_dB = -28; e.PW_s = 2e-6;
e.PRI_s = [0.95 1.02 0.98 1.05 1.00]*1e-3;   % 5-position stagger
e.scanType = 'rotating'; e.scanPeriod_s = 10; e.rotDir = +1; e.scanJitter = 0.002;
e.antHeight_m = 15;
L = [L e];

e = base();
e.id = 'FIX-C1'; e.class = 'fixed';
e.description = 'C-band acquisition radar, rotating, constant PRI';
e.fc = 5.60e9; e.fAgile = e.fc;
e.Ppeak_W = 250e3; e.G_dBi = 38; e.azBW_deg = 1.0; e.elCov_deg = [0 20];
e.SLL_dB = -30; e.PW_s = 5e-6; e.PRI_s = 2.0e-3;
e.scanType = 'rotating'; e.scanPeriod_s = 4; e.rotDir = +1; e.scanJitter = 0.003;
e.antHeight_m = 10;
L = [L e];

% ---------------- MARINE (rotating) --------------------------------------
e = base();
e.id = 'MAR-X1'; e.class = 'marine';
e.description = 'X-band navigation / surface search, rotating, 24 rpm';
e.fc = 9.41e9; e.fAgile = e.fc;
e.Ppeak_W = 25e3; e.G_dBi = 31; e.azBW_deg = 1.0; e.elCov_deg = [-11 11];
e.SLL_dB = -28; e.PW_s = 0.5e-6; e.PRI_s = 0.5e-3;
e.scanType = 'rotating'; e.scanPeriod_s = 2.5; e.rotDir = +1; e.scanJitter = 0.005;
e.antHeight_m = 25;
L = [L e];

e = base();
e.id = 'MAR-S1'; e.class = 'marine';
e.description = 'S-band naval air/surface search, rotating, 20 rpm, jittered PRI';
e.fc = 3.05e9; e.fAgile = e.fc;
e.Ppeak_W = 60e3; e.G_dBi = 30; e.azBW_deg = 2.0; e.elCov_deg = [-2 25];
e.SLL_dB = -25; e.PW_s = 1e-6; e.PRI_s = [1.00 1.03 0.97 1.01 0.99 1.02]*1e-3;
e.scanType = 'rotating'; e.scanPeriod_s = 3; e.rotDir = -1; e.scanJitter = 0.004;
e.antHeight_m = 30;
L = [L e];

% ---------------- AIRBORNE (electronically scanned) ----------------------
e = base();
e.id = 'AIR-X1'; e.class = 'airborne';
e.description = 'X-band AESA fire-control radar, raster search, frequency agile';
e.fc = 9.8e9; e.fAgile = (9.3:0.2:10.3)*1e9;   % hops across 3 filter channels
e.Ppeak_W = 12e3; e.G_dBi = 36; e.azBW_deg = 3.0; e.elCov_deg = 3.0;
e.SLL_dB = -35; e.PW_s = 3e-6; e.PRI_s = [50 56 62]*1e-6;  % MPRF set, per dwell
e.scanType = 'esa'; e.rotDir = 0; e.scanJitter = 0;
e.esaAz_deg = -60:3:60; e.esaEl_deg = [-2 1 4]; e.esaDwell_s = 5e-3;
e.scanPeriod_s = numel(e.esaAz_deg)*numel(e.esaEl_deg)*e.esaDwell_s;
e.antHeight_m = 0;
L = [L e];

lib = L;
end

function e = base()
e = struct('id','', 'class','', 'description','', 'fc',0, 'fAgile',0, ...
    'Ppeak_W',0, 'G_dBi',0, 'azBW_deg',0, 'elCov_deg',[0 0], 'SLL_dB',-30, ...
    'PW_s',0, 'PRI_s',0, 'scanType','', 'scanPeriod_s',0, 'rotDir',1, ...
    'scanJitter',0, 'esaAz_deg',[], 'esaEl_deg',[], 'esaDwell_s',0, ...
    'antHeight_m',0);
end
