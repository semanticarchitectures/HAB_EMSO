# HAB / Philowave EMSO seminar demos (MATLAB)

Demos and a shared model library for the four MathWorks seminars at Hanscom AFB. All of them are built around one scenario: **notional Philowave-class wideband filter-bank detectors on altitude-steered high-altitude balloons (HABs), used for electromagnetic spectrum operations (EMSO)** against three classes of scanning radar:

| Class | Emitters (notional) | Scan |
|---|---|---|
| Fixed sites | `FIX-S1` S-band surveillance, `FIX-C1` C-band acquisition | mechanically rotating |
| Marine | `MAR-X1` X-band navigation, `MAR-S1` S-band search | mechanically rotating |
| Airborne | `AIR-X1` X-band AESA fire control (frequency agile) | electronically scanned raster |

> **All emitter, receiver, balloon, wind and cost parameters are NOTIONAL.** They are physically plausible values chosen for teaching. They are **not** Philowave specifications and do not describe any fielded system. Public information on Philowave (2–4 octaves of instantaneous bandwidth, sub-µs response, and the 15 GHz USAF SBIR "Wideband Interference Detector") informed only the architecture. If real values are used, keep them in a separate, controlled configuration.

## Quick start
```matlab
run('<this folder>/setupPaths.m')
runCoreTests            % 13 regression tests; all pass
```
Every demo is a plain script with `%%` sections. Open it, run it section by section, or convert it to a Live Script. Every demo runs on **base MATLAB**, and toolbox features are used when they're installed (`pw.hasToolbox`).

## Seminar → demo map

| Seminar | Demo | Shows | Uses if present |
|---|---|---|---|
| **Intro to Radar Signal Processing** | `R1_emitters_and_illumination` | Waveforms, scan patterns, and what a balloon receives; deinterleaving at a single balloon | Phased Array (ULA pattern) |
| | `R2_one_way_advantage` | Radar equation; two-way radar range vs one-way intercept range | Radar Toolbox (`radareqrng`) |
| | `R3_matched_filter_vs_envelope_detector` | Pulse compression vs envelope detection; the channel-width trade | Phased Array (`LinearFMWaveform`, `MatchedFilter`) |
| | `R4_cfar_on_detector_video` | CA-CFAR against a fixed threshold on a rising noise floor | Phased Array (`CFARDetector`) |
| | `R5_beamforming_sidelobes_and_df` | AESA steering, taper and sidelobes; amplitude-comparison DF accuracy | Phased Array (ULA, `SteeringVector`) |
| **End-to-End EMSO Modeling** | `E1_sense_filterbank_signal_level` | 40 GS/s RF → 32-channel filter bank → PDWs; channel-edge straddle; comms floor rise | — |
| | `E2_understand_deinterleave_classify` | Deinterleaving, PRI histograms, scan analysis, identification, cross-balloon association | — |
| | `E3_geolocate_multi_hab` | TDOA + scan-timing hybrid geolocation; CEP maps | Phased Array (`tdoaposest` cross-check) |
| | `E4_track_moving_emitters` | 15 minutes of fixes from drifting balloons → ship tracks | Sensor Fusion (`trackerGNN`) |
| | `E5_decide_act_assess` | Repositioning balloons for a priority emitter set, then assessing the result | — |
| **Mission Engineering** | `M1_trade_space_sweep` | 432-design sweep, Pareto front, main effects | — |
| | `M2_multiobjective_optimization` | Three-objective GA over the design space | Global Optimization (`gamultiobj`) |
| | `M3_mission_thread_simulation` | 24 h mission thread from launch; time to first fix; coverage over time | — |
| | `M4_system_composer_architecture` | System-of-systems architecture with SWaP-C stereotypes | **System Composer (required)** |
| **Agentic AI** | `A1_agentic_toolkit/` | An agent drives MATLAB through the MATLAB Agentic Toolkit: run sheet, reference solution, tests, live PDW data | MATLAB Agentic Toolkit + coding agent |
| | `A2_mcp_production_server/` | Five governed MCP tools plus two MCP resources on MATLAB Production Server | MPS, Compiler SDK, MCP Framework (R2025b+) |
| | `A3_mcp_client_multiagent/` | MATLAB orchestrates a planner LLM and a critic LLM; MATLAB decides pass or fail | LLMs with MATLAB, MCP HTTP Client |

## Library (`+pw`, base MATLAB)
- **Models:** `defaultReceiver`, `emitterLibrary`, `defaultScenario`, `emitterPosition`, `boresight`, `txGain`, `generatePDWs`, `rfFrontEnd`, `windField`, `simulateHAB`.
- **Processing:** `extractPDW`, `caCFAR`, `deinterleave`, `estimatePRI`, `scanAnalysis`, `classifyEmitter`, `associateClusters`, `measureTDOA`, `buildMeasurements`, `geolocate`, `locateGroup`, `trackCV`.
- **Analysis:** `interceptRange`, `usableHABs`, `geolocationCRLB`, `evaluateDesign`, `albersheim`, `pdFromSNR`.
- **Geometry:** `lla2ecef`, `ecef2lla`, `enu`, `aer`, `groundRange`, `isVisible`, `fspl`.

## Results the demos establish (with these notional values)
1. **Scan-timing geolocation.** The time between a rotating beam sweeping two balloons gives the angle at the emitter. This lets filter-bank balloons, which have no phase or AOA hardware, geolocate rotating radars to **about 15–500 m**, depending on geometry.
2. **TDOA ambiguity.** TDOA needs the same pulse at three or more balloons, which means sidelobe intercepts. A constant PRI makes it ambiguous, so the two-stage solver uses the scan-timing fix to pick the right peak. A chi-square integrity check rejects inconsistent solutions, because a wrong-peak TDOA once gave a 140 km error with a claimed 20 m CEP.
3. **The AESA fighter is detected and identified but not geolocated** by filter-bank-only balloons. It has no swept beam, and its −35 dB sidelobes reach only about 13 km. The amplitude-comparison DF option closes the gap, at about 4× channel hardware.
4. **Station keeping is a threshold effect.** A ±3 km altitude band holds station about 45% of the time; ±4 km holds it about 95% (free drift: about 6%).
5. **Trade study.** The Pareto front is "16 channels + DF + ±4 km band", adding balloons for resilience. Coverage does *not* score identification, so the "16 channels" result needs an ID-confusion objective before anyone acts on it.

## Status and limitations
- **Tested:** the `+pw` library (13 regression tests, including a Monte Carlo consistency check on the geolocation error estimates) and every R, E and M1–M3 demo, plus the A3 offline loop. These were **run in GNU Octave 8.4 without MathWorks toolboxes**, because no MATLAB was available when the package was built. Toolbox branches, MATLAB-only syntax (A1 tests, A2 tools, A3 LLM paths, M4) and the `%%` Live Script rendering **were not executed**. Budget a dry run in MATLAB.
- **Modeling simplifications:**
  - Spherical Earth with a 4/3-Earth horizon, and no terrain masking.
  - Analytic antenna patterns.
  - Perfect wind forecasts for station keeping.
  - One wind field for all balloons.
  - No multipath.
  - No CW or noise jammers as geolocation targets (E1 shows their floor rise only).
  - The DF option is modeled analytically in the trade study, not pulse by pulse.
- `radar_datacube_clutter_cfar_01.m` (the radar seminar's own example) was not available and is not included. R4 complements it with intercept-side CFAR.
