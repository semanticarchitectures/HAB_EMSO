# A1 live demo run sheet: an agent drives MATLAB (MATLAB Agentic Toolkit)

**Seminar highlight:** *MATLAB Agentic Toolkit: see how public and private LLMs can autonomously call MATLAB to perform calculations, generate plots, and analyze live data.*

**Domain:** notional Philowave-class filter-bank detectors on altitude-steered high-altitude balloons (HABs), used for EMSO. The agent works against the tested `pw` library in this package.

## Setup (do this the day before)
1. Install the MATLAB Agentic Toolkit (github.com/matlab/matlab-agentic-toolkit). You need MATLAB R2020b or later and Git.
2. Pick a supported agent: Claude Code, GitHub Copilot, OpenAI Codex, Gemini CLI or another. **For the "private LLM" point, confirm which agent and model endpoint the venue network allows.** Commercial APIs are often blocked on base networks.
3. Open the package root folder in the agent. In MATLAB, run `setupPaths` and then `makeSampleData`.
4. Run `tests/runCoreTests` once. All 13 tests should pass.
5. Dry-run the prompts below with the exact model you'll use on stage, and save the transcript as a fallback.

## Prompts (paste in order)

| # | Prompt | Toolkit tools you should see | Point to make |
|---|---|---|---|
| 1 | *What MATLAB version and toolboxes are installed? Then run `setupPaths`.* | `detect_matlab_toolboxes`, `evaluate_matlab_code` | The agent grounds itself in the real environment before writing code. |
| 2 | *Using the `pw` package in this folder, compute the intercept range of every emitter in `pw.emitterLibrary` for a balloon at 15, 20 and 25 km altitude, in the main beam and in sidelobes. Show a table and plot range against altitude.* | `evaluate_matlab_code` (maybe several times) | It reads `help pw.interceptRange` itself. Results should match `reference/habLinkBudgetStudy.m`. |
| 3 | *Turn that into a script `habLinkBudgetStudy.m`, run Code Analyzer on it, fix any issues and run it.* | `check_matlab_code`, `run_matlab_file` | Agent output passes the same static checks as human code. |
| 4 | *Write `matlab.unittest` tests in `tHabLinkBudget.m` that check: the 20 km radio horizon is 583 ± 3 km; intercept range never exceeds the horizon; sidelobe range ≤ mainbeam range; FSPL at 10 GHz and 1 km is 112.4 dB; and adding 3 dB of noise figure divides link-limited range by 10^(3/20). Run them.* | `run_matlab_test_file` | The agent writes *and* runs verification, and the physics check (last test) is non-trivial. Compare with `reference/tHabLinkBudget.m`. |
| 5 | *`pdw_sample.csv` holds 32 s of intercepts from one balloon: TOA, channel, pulse width, amplitude. Work out how many radars are present, their PRIs and their scan periods, and say which ones rotate. Use the `pw` package if it helps.* | `evaluate_matlab_code` | Live-data analysis: the agent should find and use `pw.deinterleave`. Check against `verifyAgentAnswers`. |
| 6 | *Review `+pw/measureTDOA.m` for edge cases and suggest tests.* | Toolkit skill `matlab-reviewing-code` | Skills: packaged expertise, not just tool access. |

## What to say while it works
- The agent writes *new code every time*. That's powerful for exploration, and it's why verification (prompts 3 and 4) and review (prompt 6) matter.
- The agent's numbers are checked against a tested library (`verifyAgentAnswers`), not against the agent's own confidence.
- A2 shows the other governance model: the agent may only *call* approved tools.

## If it goes wrong
- **Agent can't find `pw`:** ask it to run `setupPaths` first.
- **Agent reimplements the physics instead of using the library:** say "use `pw.interceptRange`". This is itself a teaching moment about guiding agents.
- **Slow model or no network:** switch to the saved transcript from the dry run.
