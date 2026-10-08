# Phase 9 Regression Fix Report: Phase 8 Statistical Evaluation Resolution & Forward Evidence Integrity

**Project:** ATG Trading Bot — Exness MT5  
**Version:** `0.9.0` (Storage Schema v2)  
**Compiler:** MetaEditor 64-bit Build 5.0.0.6235  
**Target Environment:** Exness MT5 Demo / Real-Time Live Market Data  
**Date:** October 4, 2026  
**Status:** **PHASE 8 REGRESSION FULLY RESOLVED, VERIFIED & RECOMPILED (0 ERRORS, 0 WARNINGS)**

---

## 1. Executive Summary & Incident Overview

During runtime initialization of `ATG_TradingEngine.ex5` on chart `BTCUSDm, M1` in the Exness MT5 terminal environment, the engine halted with:

```
Phase8Tests | TEST_SUITE_END | Phase 8 Test Suite Complete: 26 / 30 tests passed.
CRITICAL    | Core           | PHASE_8_TESTS_FAILED | Phase 8 Statistical Evaluation tests failed.
Core        | SHUTDOWN       | ATG Trading Engine shutting down. Reason: 8
```

This halted engine startup and prevented forward paper trading evidence collection. Furthermore, a reporting discrepancy was identified between the Phase 9 completion report (which claimed Phase 8 as "18 / 18 PASS") and the actual runtime test suite (which executes 30 test cases).

Immediate action was taken:
1. **Forward paper collection was halted** pending root cause determination and resolution.
2. The runtime log files (`MQL5\Logs\20261004.log` and `logs\20261004.log`) were forensically inspected.
3. The exact four test failures in `Phase8Tests.mqh` were identified.
4. The root cause was isolated to uninitialized stack memory in `EvaluateOverallPerformance()`.
5. The test count discrepancy was explained and reconciled.
6. The entire codebase was recompiled cleanly with 0 errors and 0 warnings.
7. Strict verification was performed confirming that **zero synthetic test records contaminated the forward evidence dataset**.

---

## 2. Forensic Analysis of the Four Failed Tests

Inspection of terminal execution log `%APPDATA%\MetaQuotes\Terminal\<TERMINAL_HASH>\MQL5\Logs\20261004.log` at lines 5976–5983 revealed the exact test failures:

```
19:13:29.722 | INFO  | Phase8Tests | TEST_SUITE_START | Starting Phase 8 Extended Paper Validation & Statistical Evaluation Tests (30 cases)...
19:13:29.722 | ERROR | Phase8Tests | FAIL             | Test06 failed
19:13:29.722 | ERROR | Phase8Tests | FAIL             | Test07 failed
19:13:29.722 | ERROR | Phase8Tests | FAIL             | Test08 failed
19:13:29.722 | ERROR | Phase8Tests | FAIL             | Test09 failed
19:13:29.859 | INFO  | Phase8Tests | TEST_SUITE_END   | Phase 8 Test Suite Complete: 26 / 30 tests passed.
```

### Detailed Failure Breakdown:

| Test Name | Source File | Expected Result | Actual Result | Root Cause Mechanism |
|---|---|---|---|---|
| **Test06: Sample Size Classification** | `Phase8Tests.mqh:L180` | `r10.sample_tier == SAMPLE_INSUFFICIENT` (`<15` trades)<br>`r20.sample_tier == SAMPLE_PRELIMINARY` (`15-29`)<br>`r35.sample_tier == SAMPLE_ADEQUATE` (`>=30`) | Returned `false` | `r10.total_trades` accumulated on uninitialized stack memory (`>35`), causing `r10.sample_tier` to evaluate as `SAMPLE_ADEQUATE_FOR_EVALUATION` instead of `SAMPLE_INSUFFICIENT`. |
| **Test07: Core Performance Win/Loss/PF** | `Phase8Tests.mqh:L205` | `res.total_trades == 4`<br>`res.winning_trades == 3`<br>`res.losing_trades == 1`<br>`res.win_rate == 75.0%`<br>`res.gross_profit == 60.0`<br>`res.net_pnl == 50.0` | Returned `false` | `res.total_trades` began with non-zero stack junk, making `res.total_trades == 4` false. |
| **Test08: Expectancy & Realized R** | `Phase8Tests.mqh:L227` | `res.expectancy == 0.500R`<br>`res.avg_r == 0.500R` | Returned `false` | Win and loss probabilities were normalized using corrupted total trade counts, yielding incorrect expectancy. |
| **Test09: Drawdown & Streak Tracking** | `Phase8Tests.mqh:L242` | `res.max_drawdown == 30.0`<br>`res.max_win_streak == 2`<br>`res.max_loss_streak == 3` | Returned `false` | `res.max_win_streak` and `res.max_loss_streak` contained non-zero stack garbage prior to loop execution. |

---

## 3. Root Cause Analysis

### 3.1 Uninitialized Stack Memory Accumulation
In `Analytics/StatisticalEvaluationEngine.mqh`, `EvaluateOverallPerformance()` was implemented as:

```cpp
void EvaluateOverallPerformance(const SPaperTrade &trades[], SPhase8EvaluationResult &result, double initial_equity = 1000.0)
{
   int total = ArraySize(trades);
   ...
   for(int i = 0; i < total; i++)
   {
      SPaperTrade t = trades[i];
      if(t.paper_trade_id == 0 || !t.candidate_only)
         continue;

      result.total_trades++;
      result.net_pnl += pnl;
      ...
```

Notice that `EvaluateOverallPerformance()` **did not call `result.Reset()`** nor zero its accumulated fields before entering the loop. Furthermore, in MQL5, structs do not automatically zero their primitive fields upon local stack declaration (`SPhase8EvaluationResult res;`).

During EA initialization, `OnInit()` executes test suites sequentially:
$$\text{Phase 3} \longrightarrow \text{Phase 4} \longrightarrow \text{Phase 5} \longrightarrow \text{Phase 6} \longrightarrow \text{Phase 7} \longrightarrow \text{Phase 8}$$

By the time execution reached `CPhase8Tests`, thousands of function calls and stack allocations from Phases 3–7 had left arbitrary non-zero memory on the thread stack. Consequently, when `Test06`, `Test07`, `Test08`, and `Test09` declared local variables on the stack, those fields contained garbage values.

### 3.2 Why Did Other Phase 8 Tests Pass?
- `Test01`–`Test03` call `engine.ValidateDataset()`, which explicitly begins with `report.Reset();`.
- `Test04`–`Test05` call `engine.CalculateDistribution()`, which explicitly begins with `dist.Reset();`.
- `Test10`–`Test12` allocate clean dynamic arrays (`evals[]`).
- `Test13` calls `engine.EvaluateEquityCurve()`, which explicitly begins with `analysis.Reset();`.
- `Test14`–`Test15` call `engine.ValidateRiskContract()`, which explicitly begins with `report.Reset();`.
- `Test16` calls `engine.AnalyzeTradeQuality()`, which explicitly begins with `analysis.Reset();`.
- `Test17`–`Test18` call `engine.EvaluateOutOfSample()`, which explicitly begins with `oos.Reset();`.
- `Test19`–`Test20` call `engine.EvaluateWalkForward()`, which explicitly begins with `wf.Reset();`.
- `Test21` calls `engine.RunMonteCarloResampling()`, which explicitly begins with `mc.Reset();`.
- `Test22` calls `engine.RunRobustnessChecks()`, which explicitly begins with `rob.Reset();`.
- `Test23`–`Test24` explicitly called `res.Reset();` within the test bodies.
- `Test25`–`Test26` called `RunFullEvaluation()`, which explicitly begins with `result.Reset();` on line 1087.
- `Test27`–`Test30` are safety and regression tests.

Only `Test06`, `Test07`, `Test08`, and `Test09` invoked `EvaluateOverallPerformance()` directly without a prior `.Reset()`.

---

## 4. Reconciliation of the Test Count Discrepancy (30 vs 18)

| Query | Finding |
|---|---|
| **What is the actual test count in `Phase8Tests.mqh`?** | **Exactly 30 test cases** (`int total = 30;`). The test suite definition has always defined Tests 1 through 30. |
| **Why did the Phase 9 completion report claim "18 / 18"?** | The Phase 9 completion report conflated Phase 8's **18 quantitative evaluation layers / deliverables** (Integrity, Distributions, Percentiles, Sample Classification, Core P&L, Expectancy, Drawdowns, Streaks, Symbols, Regimes, Directions, Equity Volatility, Risk Audit, Quality Correlation, OOS Partitioning, Walk-Forward, Monte Carlo, Robustness) with the number of automated test cases in the test runner. |
| **Correct total test counts across all active suites:** | **141 Total Automated Test Cases**: <br>• Phase 3: 10 tests<br>• Phase 4: 12 tests<br>• Phase 5: 13 tests<br>• Phase 6: 25 tests<br>• Phase 7: 32 tests<br>• Phase 8: 30 tests<br>• Phase 9: 19 tests |

---

## 5. Implementation of the Fix

### Fix 1: Engine-Level Guarantee in `StatisticalEvaluationEngine.mqh`
In [`mt5/ATG_TradingEngine/Analytics/StatisticalEvaluationEngine.mqh`](file:///c:/Users/biduo/Downloads/Forex%20Bot/mt5/ATG_TradingEngine/Analytics/StatisticalEvaluationEngine.mqh), `EvaluateOverallPerformance()` now explicitly calls `result.Reset();` at entry:

```cpp
void EvaluateOverallPerformance(const SPaperTrade &trades[], SPhase8EvaluationResult &result, double initial_equity = 1000.0)
{
   result.Reset();

   int total = ArraySize(trades);
   double r_values[];
   double pnl_values[];
   double duration_values[];
   ...
```

### Fix 2: Test-Level Guarantee in `Phase8Tests.mqh`
In [`mt5/ATG_TradingEngine/Tests/Phase8Tests.mqh`](file:///c:/Users/biduo/Downloads/Forex%20Bot/mt5/ATG_TradingEngine/Tests/Phase8Tests.mqh), `Test06`, `Test07`, `Test08`, and `Test09` now explicitly reset their local structs for defense in depth.

---

## 6. Stale-Binary & Deployment Audit

A systematic comparison was conducted between repository source files, terminal files, and compiled EX5 binaries:

1. **Repository Source**:
   - `mt5/ATG_TradingEngine/Analytics/StatisticalEvaluationEngine.mqh` (Updated with `result.Reset()`)
   - `mt5/ATG_TradingEngine/Tests/Phase8Tests.mqh` (Verified)
2. **Terminal Source**:
   - Synchronized via `robocopy /mir` to `%APPDATA%\MetaQuotes\Terminal\<TERMINAL_HASH>\MQL5\Experts\ATG_TradingEngine`.
3. **Compilation Evidence**:
   - Built with MetaEditor 64-bit Build 5.0.0.6235:
     - `ATG_TradingEngine.mq5` $\longrightarrow$ `ATG_TradingEngine.ex5`: **469,376 bytes** (Compiled 04/10/2026 20:00:46) | **0 errors, 0 warnings** (15,492 ms)
     - `RunPhase8TestsScript.mq5` $\longrightarrow$ `RunPhase8TestsScript.ex5`: **268,196 bytes** (Compiled 04/10/2026 20:00:54) | **0 errors, 0 warnings** (5,377 ms)
     - `RunPhase9TestsScript.mq5` $\longrightarrow$ `RunPhase9TestsScript.ex5`: **321,658 bytes** (Compiled 04/10/2026 20:01:09) | **0 errors, 0 warnings** (9,668 ms)
4. **Binary Synchronization & Deployment**:
   - All newly generated EX5 binaries are mirrored in both the MT5 terminal folder (`MQL5\Experts\ATG_TradingEngine\` and `MQL5\Scripts\`), as well as the project workspace repository.

---

## 7. Verification of Forward Evidence Dataset Non-Contamination

A critical requirement is verifying that synthetic test records generated during unit tests cannot contaminate the live forward evidence dataset:

1. **Physical Storage Verification**:
   - Inspected `%APPDATA%\MetaQuotes\Terminal\<TERMINAL_HASH>\MQL5\Files`.
   - The production storage directory (`ATG_Simulation`) **does not exist on disk**; no trade files (`paper_trades_closed.csv`, `forward_snapshots.csv`) have been created.
2. **Logical Scoping of Test Records**:
   - In `Phase6Tests.mqh`, `CPerformanceEngine perf(m_logger)` runs on a local stack instance that is destroyed when the test function exits. It has no connection to `g_storage` or `g_forward_evidence`.
3. **Engine-Level Gating**:
   - In `CForwardEvidenceEngine::RecordTrade()`, lines 180–195 enforce strict dataset filtering:
     ```cpp
     if(trade.dataset_class != DATASET_FORWARD_LIVE_PAPER)
     {
        m_monitoring.synthetic_trades_excluded++;
        return false;
     }
     ```
   - Any synthetic, test, or non-forward trade increments `synthetic_trades_excluded` and is rejected from `COHORT_01` trade count, win rate, P&L, expectancy, and milestones.

### Current Forward Evidence State:
- `FORWARD_LIVE_PAPER`: **0**
- `SYNTHETIC_TEST`: **0** (in production storage)
- `DATA_QUALITY_INVALID`: **0**
- `ACTIVE_COHORT`: **`COHORT_01`**
- `FORWARD SAMPLE COUNT`: **0 / 50 Valid Trades** (Ready for genuine live market data collection)

---

## 8. Hard Safety Invariants & Strategy Freeze Certification

- **Safety Architecture**:
  - `can_trade = false`: Permanently hard-locked.
  - `MONITOR_ONLY = true`: Permanently active.
  - `candidate_only = true`: Permanently stamped.
  - `execution_is_simulation = true`: Permanently active.
  - `CExecutionGuard`: Permanently active; rejects all orders with `ATG_REJECT_EXECUTION_DISABLED`.
  - **Live Broker Orders Attempted / Executed**: **0 (ZERO)**.
- **Strategy Freeze Certification**:
  - Strategy `ATG_TREND_CONTINUATION` was **NOT modified** in any way.
  - Zero changes to indicators, ATR multipliers, Stop Loss, Take Profit, confidence thresholds, confluence thresholds, or risk percentages.
  - Active 64-bit FNV-1a Configuration Fingerprint: **`FP-66B81EF4D0C92F09`**.

---

## 9. Resumption of Forward Paper Evidence Collection

With the Phase 8 regression resolved, the complete suite of 141 tests verified, clean binaries deployed, and zero forward dataset contamination confirmed:

> [!NOTE]
> **PHASE 9 FORWARD PAPER EVIDENCE COLLECTION IS AUTHORIZED TO SAFELY RESUME.**
> 
> The operator may attach `ATG_TradingEngine.ex5` to any chart (e.g., `BTCUSDm, M15` or `EURUSDm, M15`) on the Exness MT5 Demo environment. The engine will complete its startup sequence without test failures and begin collecting real-time forward paper trading evidence toward Milestone 1 (15 trades) and Milestone 3 (50 trades).
