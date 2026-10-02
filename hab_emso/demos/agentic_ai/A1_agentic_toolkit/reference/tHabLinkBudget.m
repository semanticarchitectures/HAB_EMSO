classdef tHabLinkBudget < matlab.unittest.TestCase
    %THABLINKBUDGET Reference unit tests for Agentic AI demo A1, prompt 4.
    %   runtests('tHabLinkBudget')   -- the agent calls run_matlab_test_file
    properties
        Lib
        Rx
    end
    methods (TestClassSetup)
        function load(tc)
            tc.Lib = pw.emitterLibrary();
            tc.Rx  = pw.defaultReceiver();
        end
    end
    methods (Test)
        function horizonAt20km(tc)
            [~, ~, dh] = pw.isVisible([0 0 20e3], [0 0 0]);
            tc.verifyEqual(dh/1e3, 583, 'AbsTol', 3);
        end
        function rangeNeverExceedsHorizon(tc)
            for L = tc.Lib
                [R, info] = pw.interceptRange(L, tc.Rx, 20e3, L.antHeight_m, 'main');
                tc.verifyLessThanOrEqual(R, info.Rhorizon + 1e-6, L.id);
            end
        end
        function sidelobeShorterThanMainbeam(tc)
            for L = tc.Lib
                Rm = pw.interceptRange(L, tc.Rx, 20e3, L.antHeight_m, 'main');
                Rs = pw.interceptRange(L, tc.Rx, 20e3, L.antHeight_m, 'side');
                tc.verifyLessThanOrEqual(Rs, Rm, L.id);
            end
        end
        function fsplReference(tc)
            tc.verifyEqual(pw.fspl(10e9, 1e3), 112.45, 'AbsTol', 0.05);
        end
        function noiseFigureScaling(tc)
            % +3 dB noise figure -> link-limited range / 10^(3/20) (one-way R^2 law)
            L = tc.Lib(strcmp({tc.Lib.id}, 'MAR-X1'));
            rx2 = tc.Rx; rx2.noise_dBm = rx2.noise_dBm + 3; rx2.sens_dBm = rx2.sens_dBm + 3;
            [~, a] = pw.interceptRange(L, tc.Rx, 20e3, L.antHeight_m, 'side');
            [~, b] = pw.interceptRange(L, rx2,   20e3, L.antHeight_m, 'side');
            tc.verifyEqual(a.Rlink/b.Rlink, 10^(3/20), 'RelTol', 1e-9);
        end
        function outOfBandEmitterIsNotHeard(tc)
            L = tc.Lib(1); L.fc = 1.3e9;   % L-band: below the 2-18 GHz filter bank
            tc.verifyEqual(pw.interceptRange(L, tc.Rx, 20e3, 10, 'main'), 0);
        end
    end
end
