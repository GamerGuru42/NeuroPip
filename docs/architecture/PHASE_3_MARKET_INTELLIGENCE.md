# ATG Trading Engine — Phase 3: Market Intelligence & Signal Foundation

## 1. Executive Summary

Phase 3 introduces the **Market Intelligence & Signal Foundation** layer to the ATG Trading Engine. Its objective is to observe, measure, classify, and describe multi-timeframe market conditions without opening or managing live trading positions.

Phase 3 is strictly **MONITOR_ONLY**. It produces structured market features, multi-dimensional regime classifications, and candidate trade signals only (`SIGNAL_STATUS_CANDIDATE_ONLY`). Execution capabilities remain permanently hard-locked (`CCapabilities::can_trade == false`).

---

## 2. Architectural Pipeline

The Phase 3 architecture follows a unidirectional, deterministic pipeline:

```
RAW MARKET DATA (Phase 1)
       │ (MqlRates series across M1, M5, M15, H1, H4, D1)
       ▼
MARKET FEATURE ENGINE (Phase 3)
       │ (Price Structure, Volatility, Trend, Momentum, Market Structure, Spread)
       ▼
MARKET REGIME ENGINE (Phase 3)
       │ (Multi-dimensional: Trend Dimension, Volatility Dimension, Structure Dimension)
       ▼
SIGNAL ENGINE (Phase 3)
       │ (Confluence scoring, evidence collection, conflict analysis, bias vs candidate)
       ▼
┌───────────────────────────────┐
│     SIGNAL CANDIDATE ONLY     │
│  (Or NO_SIGNAL / WAIT state)  │
└──────────────┬────────────────┘
               │
               ▼
  [EXECUTION SAFETY BARRIER]
  (can_trade == false -> STOP)
```

---

## 3. Component Specifications

### 3.1 Market Feature Engine (`CMarketFeatureEngine`)

Calculates observable, mathematical features from historical closed bars (`MqlRates`) without relying on external MT5 chart indicators or asynchronous buffer synchronization.

* **Price Structure (`SPriceStructure`)**:
  - `open`, `high`, `low`, `close`, `prev_close`, `current_price`
  - `range_points`, `body_points`, `upper_wick_points`, `lower_wick_points`
  - Candle classification: `CANDLE_BULLISH`, `CANDLE_BEARISH`, `CANDLE_DOJI`
* **Volatility (`SVolatilityFeatures`)**:
  - True Range calculation: TR = max(H - L, |H - C_prev|, |L - C_prev|)
  - 14-period Wilder/Exponential ATR and point conversion
  - ATR relative to price percentage: (ATR / Close) * 100
  - Volatility state: `VOL_LOW` (ATR < 0.7 * ATR_40), `VOL_NORMAL`, `VOL_HIGH` (ATR > 1.35 * ATR_40)
* **Trend (`STrendFeatures`)**:
  - Fast MA (EMA 20) and Slow MA (EMA 50)
  - Baseline MA (SMA over available depth up to 75 bars)
  - MA slope in points over 2 bars: (EMA20_0 - EMA20_2) / (2 * Point)
  - Price distance to fast, slow, and baseline MAs in points
  - Directional consistency: proportion of bullish bars in the last 10 bars
  - Trend direction: `TREND_BULLISH`, `TREND_BEARISH`, `TREND_FLAT`
* **Momentum (`SMomentumFeatures`)**:
  - 14-period RSI (Relative Strength Index)
  - 10-period momentum in points: (Close_0 - Close_10) / Point
  - Overbought (RSI >= 70) / Oversold (RSI <= 30) flags
  - Momentum bias: `TREND_BULLISH` (RSI > 53), `TREND_BEARISH` (RSI < 47), `TREND_FLAT`
* **Market Structure (`SMarketStructureFeatures`)**:
  - 20-bar swing window high and low
  - Higher Highs (`higher_high`), Higher Lows (`higher_low`)
  - Lower Highs (`lower_high`), Lower Lows (`lower_low`)
  - Structure state: `STRUCT_HIGHER_HIGHS_LOWS`, `STRUCT_LOWER_HIGHS_LOWS`, `STRUCT_RANGING`, `STRUCT_EXPANSION`, `STRUCT_CONTRACTION`
* **Spread & Market Health (`SSpreadFeatures`)**:
  - Live Bid, Ask, spread in points
  - `spread_acceptable` threshold verification

### 3.2 Market Regime Engine (`CMarketRegimeEngine`)

Replaces simplistic one-dimensional labels with a multi-dimensional state vector across primary analysis timeframes (H4 macro, H1 trend, M15 structure, M5/M1 execution context):

1. **Trend Dimension (`ENUM_REGIME_TREND`)**:
   - `REGIME_TREND_BULLISH`: Confirmed bullish alignment on H4 + H1 EMA stacks
   - `REGIME_TREND_BEARISH`: Confirmed bearish alignment on H4 + H1 EMA stacks
   - `REGIME_TREND_SIDEWAYS`: Divergent or flat moving average slopes
2. **Volatility Dimension (`ENUM_REGIME_VOLATILITY`)**:
   - `REGIME_VOL_LOW`: Compressed ATR across M15/H1
   - `REGIME_VOL_NORMAL`: Standard historical volatility
   - `REGIME_VOL_HIGH`: ATR expansion > 1.35x normal baseline
3. **Structure Dimension (`ENUM_REGIME_STRUCTURE`)**:
   - `REGIME_STRUCT_TRENDING`: Consecutive HH/HL or LH/LL
   - `REGIME_STRUCT_CONSOLIDATING`: Range-bound swings
   - `REGIME_STRUCT_EXPANSION`: Wide range expansion
4. **Primary Composite Regime (`ENUM_ATG_MARKET_REGIME`)**:
   - `REGIME_TRENDING_BULLISH`, `REGIME_TRENDING_BEARISH`
   - `REGIME_RANGING`, `REGIME_HIGH_VOLATILITY`, `REGIME_LOW_VOLATILITY`
   - `REGIME_TRANSITION`, `REGIME_INSUFFICIENT_DATA`

### 3.3 Signal Engine & Signal Foundation (`CSignalEngine`)

Phase 3 introduces disciplined signal qualification:

* **Market Bias vs. Trade Candidate**:
  - **Market Bias**: Macro directional predisposition (e.g. H1/H4 is BULLISH).
  - **Trade Candidate**: Actionable setup with multi-timeframe confluence, structure confirmation, and no blocking conflicts.
* **No Overtrading Principle**:
  - `NO_SIGNAL` / `WAIT` is the primary and normal steady state.
  - No candidate is generated purely because an indicator has a specific reading.
  - Confluence score must exceed 0.65 with at least 3 positive evidence points.
* **Conflict Checking**:
  - Overbought RSI (RSI >= 70) strictly blocks BUY candidates.
  - Oversold RSI (RSI <= 30) strictly blocks SELL candidates.
  - Counter-trend short-term momentum (e.g. M5 divergence) suppresses candidate generation into `SIGNAL_QUALITY_WEAK` or `NO_SIGNAL`.
* **Explainability (`SATGSignalCandidate`)**:
  - Every signal candidate maintains an array of verified `evidence[]` strings and observed `conflicts[]` strings.

---

## 4. Signal Lifecycle

```
[New Bar Close / Periodic Evaluation]
              │
              ▼
   [Data Quality Gate] ──── Failed ───► Status: INSUFFICIENT_DATA
              │ Passed
              ▼
  [Feature & Regime Computation]
              │
              ▼
  [Confluence & Conflict Analysis]
              │
        ┌─────┴─────────────────────────┐
        ▼                               ▼
 [Score < 0.65 / Conflict]     [Score >= 0.65 & Clear]
        │                               │
        ▼                               ▼
 Quality: NONE / WEAK          Quality: CANDIDATE / STRONG_CANDIDATE
 Status: NO_SIGNAL             Status: CANDIDATE_ONLY
 Action: WAIT                  Action: LOG DIAGNOSTIC -> STOP (NO ORDER)
```

---

## 5. Data Quality Requirements

The signal and intelligence engines strictly refuse to generate speculative candidates when data is inadequate:

1. **Minimum Bar Depth**: Requires at least 30 closed historical bars per timeframe.
2. **Missing History**: If `CopyRates()` returns fewer than required bars, primary regime transitions to `REGIME_INSUFFICIENT_DATA`.
3. **Invalid Price or Point**: Zero or negative prices/points invalidate feature calculation immediately.
4. **Unacceptable Spread**: Live spread exceeding broker tolerances automatically blocks candidate qualification.

---

## 6. Execution Safety Boundary

Phase 3 maintains complete physical and logical isolation from broker order placement:

* **No Order Placement APIs**: No calls to `OrderSend()`, `CTrade::Buy()`, `CTrade::Sell()`, or `PositionOpen()`.
* **Capabilities Hard-Lock**:
  ```mql5
  CCapabilities::can_monitor = true;
  CCapabilities::can_analyze = true;  // Phase 3 Enabled
  CCapabilities::can_trade   = false; // Live Trading Permanently Disabled
  ```
* **Execution Guard Verification**:
  `CExecutionGuard` intercepts any simulated or stray intent and rejects with `ATG_REJECT_EXECUTION_DISABLED`.
* **Candidate Status**: All emitted signals are marked `SIGNAL_STATUS_CANDIDATE_ONLY`.
