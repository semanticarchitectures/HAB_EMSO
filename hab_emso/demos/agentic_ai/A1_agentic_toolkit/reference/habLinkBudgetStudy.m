%% habLinkBudgetStudy - reference answer for Agentic AI demo A1, prompts 2-3
% Intercept range of each notional emitter by a HAB at 15/20/25 km,
% mainbeam and sidelobe, with the radio horizon for comparison.
% (What a good agent-written script should look like; compare live.)
setupPaths;
lib = pw.emitterLibrary(); rx = pw.defaultReceiver(); k = pw.const();
alts_km = [15 20 25];
Rm = zeros(numel(lib), numel(alts_km)); Rs = Rm;
for i = 1:numel(lib)
    for a = 1:numel(alts_km)
        Rm(i,a) = pw.interceptRange(lib(i), rx, alts_km(a)*1e3, lib(i).antHeight_m, 'main')/1e3;
        Rs(i,a) = pw.interceptRange(lib(i), rx, alts_km(a)*1e3, lib(i).antHeight_m, 'side')/1e3;
    end
end
fprintf('%-8s', 'emitter'); fprintf('  main@%2dkm', alts_km); fprintf('  side@%2dkm', alts_km); fprintf('\n');
for i = 1:numel(lib)
    fprintf('%-8s', lib(i).id); fprintf('%10.0f', Rm(i,:)); fprintf('%10.0f', Rs(i,:)); fprintf('\n');
end
hor = sqrt(2*k.kEff*k.Re*alts_km*1e3)/1e3;
fprintf('%-8s', 'horizon'); fprintf('%10.0f', hor); fprintf('\n');
figure('Name','HAB intercept range'); 
subplot(1,2,1); plot(alts_km, Rm, 'o-'); hold on; plot(alts_km, hor, 'k--');
grid on; title('mainbeam'); xlabel('HAB altitude (km)'); ylabel('range (km)');
legend([{lib.id} {'horizon'}], 'Location', 'southeast');
subplot(1,2,2); semilogy(alts_km, Rs, 'o-'); grid on; title('sidelobes');
xlabel('HAB altitude (km)');
