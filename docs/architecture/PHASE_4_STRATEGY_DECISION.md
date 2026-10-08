# ATG Trading Engine — Phase 4: Strategy Decision Engine & Signal Validation

## 1. Executive Summary

Phase 4 implements the **Strategy Decision Engine & Signal Validation** layer for the ATG Trading Engine. Siting directly above the Phase 3 Market Intelligence layer, Phase 4 transforms descriptive market conditions into a disciplined, rule-based strategy qualification framework.

Phase 4 answers the core question:
> *"Given the current multi-timeframe market state, regime classification, and confluence evidence, is this a sufficiently strong, coherent, and qualified trade opportunity?"*

The system is strictly **MONITOR_ONLY**. The only permitted outcomes are:
- `STRATEGY_APPROVED` (Approved as a **STRATEGY CANDIDATE ONLY**)
- `STRATEGY_WAIT` (Observing market, waiting for valid confluence setup)
- `STRATEGY_REJECTED` (Disqualified by one or more validation quality gates)
- `STRATEGY_INSUFFICIENT_DATA` (Inadequate historical data or invalid parameters)

Under **NO CIRCUMSTANCES** does Phase 4 initiate live order execution. `CCapabilities::can_trade` remains permanently set to `false`.

---

## 2. Architecture & Pipeline

Phase 4 extends the ATG pipeline hierarchically without bypassing earlier phases:

```
RAW MARKET DATA (Phase 1)
       │ (MqlRates across M1, M5, M15, H1, H4, D1)
       ▼
MARKET FEATURE ENGINE (Phase 3)
       │ (Price structure, volatility, trend, momentum, market structure, spread)
       ▼
MARKET REGIME ENGINE (Phase 3)
       │ (Multi-dimensional: Trend, Volatility, Structure)
       ▼
SIGNAL FOUNDATION (Phase 3)
       │ (Confluence scoring, evidence collection, conflict analysis, bias vs candidate)
       ▼
STRATEGY DECISION ENGINE (Phase 4)
       │ [ATG_TREND_CONTINUATION]
       │ (Deconstructed scoring, multi-timeframe hierarchy, duplicate control)
       ▼
SIGNAL VALIDATION (Phase 4)
       │ [9 Multi-Gate Quality Verification]
       ▼
STRATEGY CANDIDATE ONLY
  (Or STRATEGY_WAIT / STRATEGY_REJECTED)
       │
       ▼
[EXECUTION SAFETY BARRIER]
(can_trade == false -> STOP)
```

---

## 3. Strategy Decision Contract (`SStrategyDecision`)

The decision layer operates via the `SStrategyDecision` data contract:

| Field | Type | Description |
| :--- | :--- | :--- |
| `decision_id` | `ulong` | Unique incremental identifier for each evaluation |
| `symbol` | `string` | Target instrument (e.g. `EURUSDm`, `BTCUSDm`) |
| `primary_timeframe` | `ENUM_TIMEFRAMES` | Base execution timeframe (`PERIOD_M15`) |
| `direction` | `ENUM_ATG_SIGNAL_DIRECTION` | `SIGNAL_DIR_BUY`, `SIGNAL_DIR_SELL`, or `SIGNAL_DIR_NONE` |
| `status` | `ENUM_STRATEGY_DECISION_STATUS` | `STRATEGY_WAIT`, `STRATEGY_CANDIDATE`, `STRATEGY_APPROVED`, `STRATEGY_REJECTED` |
| `strategy_id` | `string` | Unique strategy identifier (`"ATG_TREND_CONTINUATION"`) |
| `strategy_version` | `string` | Semantic strategy version (`"1.0.0"`) |
| `confidence` | `double` | Statistical confluence from intelligence layer ($0.0$ to $1.0$) |
| `quality_score` | `double` | Deconstructed composite score ($0.0$ to $1.0$) |
| `score_breakdown` | `SStrategyConfluenceScore` | Transparent weights across trend, structure, momentum, volatility, spread, TF agreement |
| `primary_regime` | `ENUM_ATG_MARKET_REGIME` | Contextual regime from Phase 3 |
| `market_bias` | `ENUM_ATG_MARKET_BIAS` | Macro directional bias (`BIAS_BULLISH` or `BIAS_BEARISH`) |
| `supporting_evidence[]`| `string[]` | Human-readable bulleted points of affirmative evidence |
| `conflicting_evidence[]`| `string[]` | Human-readable bulleted points of active conflicts or gate failures |
| `rejection_reason` | `ENUM_STRATEGY_REJECTION_REASON` | Explicit programmatic failure code |
| `rejection_detail` | `string` | Detailed narrative of rejection rationale |
| `created_time` | `datetime` | Evaluation timestamp |
| `bar_time` | `datetime` | Timestamp of the closed bar evaluated |
| `expiry_time` | `datetime` | Validity horizon of the candidate |
| `is_approved` | `bool` | True if candidate meets all gates (**CANDIDATE ONLY — NO LIVE EXECUTION**) |
| `formatted_explanation` | `string` | Human-readable explanation block |

---

## 4. Decision States & Lifecycle

Phase 4 defines an explicit, deterministic state machine:

```
[Phase 3 Signal Candidate Received]
              │
              ▼
       STRATEGY_CANDIDATE
              │
              ▼
   [9-Gate Strategy Validation]
        ┌─────┴─────────────────────────┐
        ▼                               ▼
  [All Gates Passed]              [Gate Failed]
        │                               │
        ▼                               ▼
 STRATEGY_APPROVED               STRATEGY_REJECTED
(Approved as Candidate ONLY)     (Recorded with Reason & Detail)
        │                               │
        ▼                               ▼
      STOP                            WAIT
```

- **`STRATEGY_WAIT`**: Default steady state. 100 market evaluations producing 0 candidates is normal, expected behavior.
- **`STRATEGY_CANDIDATE`**: Initial state when entering evaluation.
- **`STRATEGY_APPROVED`**: Candidate passed all 9 quality gates with sufficient confluence score. **Does NOT authorize live execution.**
- **`STRATEGY_REJECTED`**: Candidate failed one or more gates (e.g. excessive spread, incompatible regime, counter-trend higher timeframe).
- **`STRATEGY_INSUFFICIENT_DATA`**: Refusal to evaluate due to missing history, disconnected feeds, or zero point/prices.
- **`STRATEGY_EXPIRED`**: Candidate has exceeded its validity lifetime (`signal_expiry_sec`).

---

## 5. Multi-Timeframe Hierarchy

Decision authority follows a strict top-down multi-timeframe hierarchy:

```
D1   (Macro Context: Major structural levels and overall trend)
 │
 ▼
H4   (Macro Regime: Directional bias filter — Cannot be opposed by lower timeframes)
 │
 ▼
H1   (Primary Trend: EMA 20/50 alignment and moving-average slope)
 │
 ▼
M15  (Setup & Structure: Swings, HH/HL, LL/LH, ATR volatility, 14-period RSI)
 │
 ▼
M5   (Tactical Timing: Confirms immediate directional momentum)
 │
 ▼
M1   (Micro Filter: Subordinated — Cannot override H1/H4 structure)
```

**Golden Rule**: Lower timeframes (M1, M5) cannot override a conflicting higher timeframe (H1, H4) market structure. If H4 is Bearish, a Bullish M15/M5 signal is strictly rejected.

---

## 6. Transparent Confluence Scoring Model

The strategy replaces opaque black-box calculations with a deconstructed, transparent confluence breakdown:

$$\text{Composite Score} = \left( \sum W_i \cdot S_i \right) - \text{Conflict Penalty}$$

| Component | Weight | Measurement Source | Description |
| :--- | :---: | :--- | :--- |
| **Trend Score** | $0.25$ | H1 + H4 EMA alignment & slope | Trend consistency across primary & macro timeframes |
| **Structure Score** | $0.20$ | M15 Swings (HH/HL or LH/LL) | Price action continuation confirmation |
| **Momentum Score** | $0.20$ | M15 RSI (14) & Momentum (10) | Healthy momentum zone without exhaustion |
| **Volatility Score** | $0.15$ | M15 ATR ratio to 40-period baseline | Tradable volatility range ($0.85$ to $1.25$ ratio) |
| **Spread Score** | $0.10$ | Live tick spread vs max tolerance | Liquidity and cost-of-trade penalty |
| **TF Agreement** | $0.10$ | Proportion of aligned TFs (4 TFs) | Directional confluence across H4, H1, M15, M5 |
| **Conflict Penalty** | Subtracted | $0.15$ per active conflict | Damping factor for divergences or warnings |

---

## 7. Strategy Quality Gates

Every candidate must clear **9 distinct quality gates** to earn `STRATEGY_APPROVED` status:

1. **`DATA_VALID`**: Validates bar arrays, price structure validity, and data health.
2. **`REGIME_COMPATIBLE`**: Verifies compatibility with market regime. `ATG_TREND_CONTINUATION` requires trending regime (`TRENDING_BULLISH` for BUY, `TRENDING_BEARISH` for SELL). Rejects `RANGING` and `LOW_VOLATILITY`.
3. **`TIMEFRAME_ALIGNMENT`**: Requires $\ge 3$ of 4 timeframes aligned. Forbids higher timeframe (H4) opposing the trade direction.
4. **`STRUCTURE_VALID`**: BUY requires Higher-Highs/Higher-Lows structure. SELL requires Lower-Highs/Lower-Lows structure.
5. **`MOMENTUM_VALID`**: BUY requires RSI between $45.0$ and $68.0$ (strictly blocks $RSI \ge 70.0$). SELL requires RSI between $32.0$ and $55.0$ (strictly blocks $RSI \le 30.0$).
6. **`VOLATILITY_VALID`**: ATR $\ge 8.0$ points and ATR ratio $\le 1.80$ (filters out dead or hyper-volatile conditions).
7. **`SPREAD_VALID`**: Live spread $\le 35$ points (configurable).
8. **`CONFLICT_CHECK`**: Blocks if multiple conflicts exist or if a critical divergence is detected.
9. **`CONFIDENCE_THRESHOLD`**: Requires confidence $\ge 0.75$ and composite score $\ge 0.70$.

---

## 8. Duplicate Signal Suppression

To prevent duplicate candidate emissions on every timer tick:
- Tracks `last_evaluated_bar_time` per symbol.
- Once an M15 bar has been evaluated, subsequent calls on the same bar timestamp are suppressed from re-emitting diagnostics.
- Processing re-arms automatically upon detection of a new closed bar.

---

## 9. Execution Safety Boundary

Phase 4 maintains strict isolation from trade execution:

```
[Strategy Decision: APPROVED]
              │
              ▼
   [CANDIDATE ONLY RECORD]
              │
              ▼
 [STOP — LIVE TRADING DISABLED]
 (can_trade == false -> Execution Guard Rejection)
```

- **Zero live execution APIs**: Repository contains zero calls to `OrderSend()`, `CTrade.Buy()`, `CTrade.Sell()`, or `PositionOpen()`.
- **Hard-Locked Capabilities**: `CCapabilities::can_trade` remains `false`.
- **Execution Guard**: Actively monitors and rejects any stray or synthetic intents with `ATG_REJECT_EXECUTION_DISABLED`.

---

## 10. Future Extension Points

The Phase 4 architecture is modularly designed to support future expansions without rewriting core infrastructure:
- Additional strategies (e.g. `ATG_MEAN_REVERSION`, `ATG_BREAKOUT`) can be implemented as peer modules implementing the `SStrategyDecision` contract.
- External research inputs (e.g. Cloud AI macro analysis, news calendar filters) can plug in as additional gates in `CStrategyValidator`.
