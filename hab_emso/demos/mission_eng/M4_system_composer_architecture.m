%% M4 - System-of-Systems Architecture Model (System Composer)  [OPTIONAL]
% Seminar: Mission Engineering -- MBSE complementing mission engineering
%
% Builds a System Composer architecture for the HAB EMSO system of
% systems, with a stereotype profile carrying the same SWaP-C and
% performance parameters the trade study uses (pw.evaluateDesign), so the
% architecture model and the analysis stay consistent:
%
%   HAB_EMSO_SoS
%    |- HAB_Constellation  (Balloon_Bus: Altitude_Control, Power, Datalink, GNSS_Timing;
%    |                      Philowave_Payload: Filter_Bank, Envelope_Detectors,
%    |                      PDW_Former, [DF_Antennas])
%    |- Ground_Processing  (Deinterleave, Identify, Geolocate, Track)
%    |- Mission_Operations (Decide, Station_Commanding, Assess)
%   Flows: RF_Emissions -> PDWs -> Emitter_Reports -> Tracks -> Station_Commands
%
% STATUS: written against the documented System Composer API but NOT
% executed by the author (no MATLAB available when this package was
% built). Run in R2023b+ with System Composer; fix-ups, if any, should be
% minor (API names are listed in comments).

if ~pw.hasToolbox('syscomp')
    error('M4 requires System Composer.');
end
setupPaths;
M = pw.evaluateDesign(struct());           % baseline numbers to annotate
mdlName = 'HAB_EMSO_SoS';
if bdIsLoaded(mdlName), close_system(mdlName, 0); end
if exist([mdlName '.slx'], 'file'), delete([mdlName '.slx']); end

%% 1. Profile with stereotypes (SWaP-C / performance properties)
profName = 'HAB_EMSO_Profile';
if exist([profName '.xml'], 'file'), delete([profName '.xml']); end
prof = systemcomposer.profile.Profile.createProfile(profName);
stP = prof.addStereotype('Payload', 'AppliesTo', 'Component');
stP.addProperty('Mass', 'Type', 'double', 'Units', 'kg', 'DefaultValue', '0');
stP.addProperty('Power', 'Type', 'double', 'Units', 'W', 'DefaultValue', '0');
stP.addProperty('UnitCost', 'Type', 'double', 'Units', 'USD', 'DefaultValue', '0');
stP.addProperty('Channels', 'Type', 'double', 'DefaultValue', '32');
stB = prof.addStereotype('BalloonBus', 'AppliesTo', 'Component');
stB.addProperty('AltBandHalf', 'Type', 'double', 'Units', 'km', 'DefaultValue', '4');
stB.addProperty('FracOnStation', 'Type', 'double', 'DefaultValue', '0');
stC = prof.addStereotype('Constellation', 'AppliesTo', 'Component');
stC.addProperty('NumHAB', 'Type', 'double', 'DefaultValue', '4');
stC.addProperty('RingRadius', 'Type', 'double', 'Units', 'km', 'DefaultValue', '45');
stC.addProperty('EffGeoCoverage', 'Type', 'double', 'DefaultValue', '0');
prof.save;

%% 2. Top-level architecture
model = systemcomposer.createModel(mdlName);
model.applyProfile(profName);
arch = model.Architecture;
top = arch.addComponent({'HAB_Constellation', 'Ground_Processing', 'Mission_Operations'});
[con, gnd, ops] = deal(top(1), top(2), top(3));

addPortPair(con, gnd, 'PDWs');
addPortPair(gnd, ops, 'Emitter_Reports');
addPortPair(ops, con, 'Station_Commands');
env = arch.addComponent('EM_Environment');
addPortPair(env, con, 'RF_Emissions');

%% 3. Decompose the constellation, payload and ground processing
bus = con.Architecture.addComponent('Balloon_Bus');
pay = con.Architecture.addComponent('Philowave_Payload');
bus.Architecture.addComponent({'Altitude_Control', 'Power', 'Datalink', 'GNSS_Timing'});
pay.Architecture.addComponent({'Filter_Bank', 'Envelope_Detectors', 'PDW_Former', 'DF_Antennas_Option'});
gnd.Architecture.addComponent({'Deinterleave', 'Identify', 'Geolocate', 'Track'});
ops.Architecture.addComponent({'Decide', 'Station_Commanding', 'Assess'});

%% 4. Apply stereotypes and the trade-study values
con.applyStereotype([profName '.Constellation']);
con.setProperty([profName '.Constellation.NumHAB'], num2str(M.design.nHAB));
con.setProperty([profName '.Constellation.RingRadius'], num2str(M.design.ringRadius_km));
con.setProperty([profName '.Constellation.EffGeoCoverage'], sprintf('%.3f', M.effGeoCoverage));
pay.applyStereotype([profName '.Payload']);
pay.setProperty([profName '.Payload.Mass'], sprintf('%.2f', M.payloadMass_kg));
pay.setProperty([profName '.Payload.Power'], sprintf('%.1f', M.payloadPower_W));
pay.setProperty([profName '.Payload.UnitCost'], sprintf('%.0f', M.rx.unitCost_USD));
pay.setProperty([profName '.Payload.Channels'], num2str(M.rx.nChannels));
bus.applyStereotype([profName '.BalloonBus']);
bus.setProperty([profName '.BalloonBus.AltBandHalf'], num2str(M.design.altBandHalf_km));
bus.setProperty([profName '.BalloonBus.FracOnStation'], sprintf('%.2f', M.fracOnStation));

Simulink.BlockDiagram.arrangeSystem(mdlName);
model.save;
fprintf('Saved %s.slx with profile %s.xml\n', mdlName, profName);
fprintf(['Next steps: create a view per stakeholder (payload SWaP, ground\n' ...
         'processing), link requirements (Requirements Toolbox) to the\n' ...
         'stereotype properties, and drive pw.evaluateDesign from them.\n']);

% Helper addPortPair.m is in ./private
