function tf = hasToolbox(name)
%PW.HASTOOLBOX True if a MathWorks toolbox is installed and licensed.
%   tf = pw.hasToolbox('phased')   Phased Array System Toolbox
%        'radar'  Radar Toolbox          'fusion'  Sensor Fusion and Tracking
%        'gads'   Global Optimization    'map'     Mapping Toolbox
%        'signal' Signal Processing      'syscomp' System Composer
%   Always false in GNU Octave, so demos fall back to the pw library.
tf = false;
if exist('OCTAVE_VERSION','builtin'), return; end
switch lower(name)
    case 'phased',  lic = 'Phased_Array_System_Toolbox'; fn = 'phased.ULA';
    case 'radar',   lic = 'Radar_Toolbox';               fn = 'radareqrng';
    case 'fusion',  lic = 'Sensor_Fusion_and_Tracking';  fn = 'trackerGNN';
    case 'gads',    lic = 'GADS_Toolbox';                fn = 'gamultiobj';
    case 'map',     lic = 'MAP_Toolbox';                 fn = 'geoplot';
    case 'signal',  lic = 'Signal_Toolbox';              fn = 'pspectrum';
    case 'syscomp', lic = 'System_Composer';             fn = 'systemcomposer.createModel';
    otherwise, return
end
try
    tf = license('test', lic) && (exist(fn,'file') > 0 || exist(fn,'class') > 0);
catch
    tf = false;
end
end
