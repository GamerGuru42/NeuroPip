# NeuroPip — Autonomous Live Status Dashboard (Phase J Dual-Track)

**Product:** NeuroPip  
**Organization:** NextGen Technologies  
**Phase:** Phase J — Isolated Track B Launch & Baseline Verification  
**Last Updated:** `2026-10-09T19:05:00Z`

---

## 1. Dual-Track Operational Status

| Parameter | Track A (Production Baseline) | Track B (Experimental Validation) |
|---|---|---|
| **Branch** | `main` | `feat/strategy-alternatives` |
| **Process ID (PID)** | `21304` | `13248` |
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

---

## 2. Market Data Universe Synchronization

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

## 3. Signal & Trade Integrity Enforcements

- **Completed Candle Rule:** Track B evaluates entries exclusively upon bar close of H1 candles (`BarDataManager::NEW_BAR`).
- **Spread & Sizing Gates:** Real-time Gate 7 spread-to-ATR ratio ($\le 15\%$) and position-sizing risk constraints ($\le 1\%$) are enforced in the running binaries.
- **Organic Forward Evidence:** No synthetic trades are counted toward forward evidence. Forward $N$ increments strictly upon genuine market-driven paper trade closure.
