# NeuroPip — Autonomous Live Status Dashboard

**Product:** NeuroPip  
**Organization:** NextGen Technologies  
**Phase:** Phase G — Autonomous DEMO Execution & Forward Validation  
**Last Updated:** `2026-10-08T13:30:00Z`

---

## 1. Safety & Execution Invariants

| Invariant Parameter | Value | Status |
|---|---|---|
| **Real Trading Allowed (`can_trade`)** | `false` | **ENFORCED (DISABLED)** |
| **Operational Mode** | `MONITOR_ONLY` | **ENFORCED** |
| **Strategy Fingerprint** | `FP-B741A5209E579706` | **100% UNCHANGED** |
| **Risk Percentage** | `1.0%` per trade | **FROZEN** |
| **Stop Loss Formula** | $2.0 \times \text{ATR}$ | **FROZEN** |
| **Take Profit Formula** | $2.0 \times \text{RR}$ | **FROZEN** |
| **Minimum Risk:Reward** | $\ge 1.50$ | **FROZEN** |
| **Max Spread Qualification** | `35 points` (Strategy filter) | **FROZEN** |
| **Max Spread Tolerance** | `40 points` (Trade Planner) | **FROZEN** |
| **ExecutionGuard Intercept** | Active (`ATG_REJECT_EXECUTION_DISABLED`) | **PASS** |

---

## 2. Terminal & Runtime State

- **Active Process PID:** `14664` (`terminal64.exe`)
- **Attached Expert:** `NeuroPip_EA` (`MQL5\Experts\NeuroPip\NeuroPip_EA.mq5` compiled to `.ex5`)
- **Host Chart:** `BTCUSDm`, Timeframe: `M1`
- **Broker / Server:** `Exness-MT5Trial9`
- **Account Number:** `477430016` (Hedging Account)
- **Account Environment:** **DEMO ONLY** (`demo account - hedging mode`)
- **Terminal Data Directory:** `%APPDATA%\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06`
- **Log Streaming Freshness:** $< 5\text{ seconds}$

---

## 3. Market Data Universe Synchronization

All 5 core assets are synchronized across all 6 timeframes (`M1`, `M5`, `M15`, `H1`, `H4`, `D1`):

| Symbol | Status | Current Spread | Timeframe Health | Tick Heartbeat |
|---|---|---|---|---|
| `EURUSDm` | **READY** | $8\text{ pts}$ | 6/6 Synced | Stream Active |
| `USDJPYm` | **READY** | $10\text{ pts}$ | 6/6 Synced | Stream Active |
| `XAUUSDm` | **READY** | $240\text{ pts}$ | 6/6 Synced | Stream Active |
| `BTCUSDm` | **READY** | $640\text{ pts}$ | 6/6 Synced | Stream Active |
| `ETHUSDm` | **READY** | $100\text{ pts}$ | 6/6 Synced | Stream Active |

**Overall Market Data Health:** **5/5 symbols healthy**.

---

## 4. Forward Evidence Accumulation ($N$)

- **Active Cohort:** `COHORT_01`
- **Genuine Forward Trades ($N$):** **0**
- **Synthetic Unit/Regression Tests:** **161 / 161 Passed** (100%)
- **Open Positions:** 0
- **Closed Positions:** 0
- **Total Realized P&L:** `0.00 USD`
- **Max Drawdown:** `0.00%`
- **Win Rate:** `N/A` (Awaiting $N \ge 15$)
- **Profit Factor:** `N/A` (Awaiting $N \ge 15$)

### Milestone Trajectory:
- **Milestone 1 ($N = 15$):** Pending accumulation (Target: $PF \ge 1.30$, $\text{MaxDD} \le 5.0\%$)
- **Milestone 2 ($N = 30$):** Scheduled
- **Milestone 3 ($N = 50$):** Scheduled
- **Milestone 4 ($N = 75$):** Scheduled
- **Milestone 5 ($N = 100$):** Final Forward Gate

---

## 5. Execution Pipeline Verification

The 7-stage order construction and preflight pipeline was validated during initialization:
1. **Signal Generation:** Deterministic strategy signal evaluation validated across all symbols.
2. **Trade Plan Construction:** Correct entry price, SL ($2.0 \times \text{ATR}$), and TP ($2.0 \times \text{RR}$) calculated.
3. **Risk Sizing:** Volatility-adjusted lot sizing checked against broker minimum volume ($0.01$) and step.
4. **Order Construction:** MQL5 `MqlTradeRequest` built with correct magic number, type, and stop levels.
5. **Preflight Validation:** Broker `OrderCheck` returned code `10027` (execution disabled by policy preflight).
6. **ExecutionGuard Safety Block:** `ATG_REJECT_EXECUTION_DISABLED` triggered, preventing broker order transmission.
7. **Reconciliation & Persistence:** Audit log recorded preflight check cleanly in `ATG_Phase9_Storage`.

---

## 6. Runtime Supervisor & Recovery

- **Supervisor Component:** `monitoring/runtime_supervisor.py`
- **Task Scheduler Task:** `\Launch_MT5_ATG`
- **Crash Recovery Tested:** Pass (Automatic chart restore and restart capability intact)
- **Stale EA Detection:** Log age threshold $45\text{s}$ actively monitored.
