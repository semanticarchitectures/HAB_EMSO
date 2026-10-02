# HAB_EMSO

MATLAB demos and a shared model library for a set of MathWorks seminars at Hanscom AFB. They are built around one scenario: notional Philowave-class wideband filter-bank detectors on altitude-steered high-altitude balloons (HABs), used for electromagnetic spectrum operations (EMSO) against fixed, marine and airborne scanning radars.

> **All emitter, receiver, balloon, wind and cost parameters are NOTIONAL.** They are plausible teaching values. They are not Philowave specifications and do not describe any fielded system.

## Layout

| Folder | Contents |
|---|---|
| [`hab_emso/`](hab_emso/README.md) | The `+pw` model library, 13 regression tests, and demos for four seminars: Radar Signal Processing (R1–R5), End-to-End EMSO (E1–E5), Mission Engineering (M1–M4) and Agentic AI (A1–A3) |
| [`matlab-mcp-kit/`](matlab-mcp-kit/README.md) | Setup for connecting Claude to MATLAB through the official MATLAB MCP Server, with six HAB functions exposed as custom tools |

## Quick start

```matlab
run('hab_emso/setupPaths.m')
runCoreTests          % 13 regression tests
```

Each demo is a sectioned script that runs on base MATLAB and uses a toolbox when one is installed and licensed.

## Status

- **Run in MATLAB R2025b (macOS) and GNU Octave 8.4:** the 13 regression tests, R1–R5, E1–E5, M1–M3, the A1 reference script and unit tests, the A2 tool functions, and the A3 offline loop.
- **Not yet run:** the toolbox-specific branches (Phased Array, Radar, Sensor Fusion, Global Optimization), M4 (System Composer), the A2 build and deploy (Compiler SDK and MATLAB Production Server), and the A3 LLM paths.
- **Known issue:** the closing "lesson" text in `E5_decide_act_assess.m` is fixed text and can contradict the numbers from a given run.

No license has been chosen for this repository yet.
