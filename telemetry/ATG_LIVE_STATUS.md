# NeuroPip — Autonomous Live Status Dashboard (Phase L Evidence Accumulation)

**Product:** NeuroPip  
**Organization:** NextGen Technologies  
**Phase:** Phase L — Forward Evidence Accumulation & Runtime Audit  
**Last Updated:** `2026-10-10T23:15:00Z` (Local `2026-10-11T00:15:00+01:00`)

---

## 1. Dual-Track Operational Status

| Parameter | Track A (Production Baseline) | Track B (Experimental Validation) |
|---|---|---|
| **Branch** | `main` | `feat/strategy-alternatives` |
| **Process ID (PID)** | `13564` | `11672` |
| **Terminal Directory** | `%APPDATA%\...\53785E099C92...` | `C:\Users\biduo\MT5_TrackB` |
| **Strategy ID** | `NEUROPIP_TREND_CONTINUATION` | `NEUROPIP_MOMENTUM_BREAKOUT` |
| **Active Cohort** | `COHORT_01` | `COHORT_EXP_01` |
| **Cryptographic Fingerprint** | `FP-B741A5209E579706` | `FP-B99C07129CE43DE8` |
| **Timeframe** | `PERIOD_M15` | `PERIOD_H1` |
| **Simulated Equity** | `$10.00` | `$1,000.00` |
| **Take-Profit Multiplier** | $2.0 \times \text{RR}$ | $2.5 \times \text{RR}$ |
| **Real Trading (`can_trade`)** | `false` | `false` |
| **Operational Mode** | `MONITOR_ONLY` | `MONITOR_ONLY` |
| **ExecutionGuard** | **LOCKED** | **LOCKED** |
| **Forward Sample ($N$)** | **0** | **0** |
| **Open Paper Positions** | **0** | **0** |
| **Cumulative Paper P/L** | `$0.00` | `$0.00` |
| **Profit Factor** | *N/A (N=0)* | *N/A (N=0)* |
| **Maximum Drawdown** | `$0.00 (0.00%)` | `$0.00 (0.00%)` |

---

## 2. Market Data Universe Synchronization

All 5 core assets are synchronized across all timeframes. Crypto assets trade 24/7/365 while FX/Gold are currently in weekend close:

| Symbol | Status | Current Spread | Session State | Last Tick Heartbeat |
|---|---|---|---|---|
| `EURUSDm` | **READY** | $8\text{ pts}$ | Weekend Closed | `2026.10.09 20:58:55` |
| `USDJPYm` | **READY** | $26\text{ pts}$ | Weekend Closed | `2026.10.09 20:58:57` |
| `XAUUSDm` | **READY** | $260\text{ pts}$ | Weekend Closed | `2026.10.09 20:57:59` |
| `BTCUSDm` | **READY** | $640\text{ pts}$ | **LIVE 24/7** | `2026.10.10 23:14:14` |
| `ETHUSDm` | **READY** | $100\text{ pts}$ | **LIVE 24/7** | `2026.10.10 23:14:13` |

**Overall Market Data Health:** **5/5 symbols healthy**. Fresh tick heartbeats are actively streaming on live instruments.

---

## 3. Forward Evidence Accumulation & Signal Gates

- **Completed Candle Rule:** Track B evaluates entries exclusively upon bar close of H1 candles. Last completed H1 bar synchronized: `22:00` (in-progress bar: `23:00`).
- **Qualification / Rejection Breakdown:** Evaluated candidate setups: 5. Setups approved: 0. Rejections: Market structure in consolidation; RSI within neutral zone (45–55); Donchian 20 channel bounds unbreached; ATR volatility expansion threshold ($\ge 1.25\times$) not met.
- **Evidence Integrity:** No synthetic or forced trades. Forward $N$ increments strictly upon genuine market-driven paper trade closures.
