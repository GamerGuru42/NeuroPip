# ATG Trading Engine — Phase 5: Trade Planning, Risk Integration & Position Sizing

## 1. Executive Summary

Phase 5 implements the **Trade Planning, Risk Integration & Position Sizing** layer for the ATG Trading Engine.
Building upon the verified Phase 4 Strategy Decision Engine, Phase 5 converts approved strategy candidates into complete, explainable, risk-bounded, and broker-validated **Trade Plans**.

Phase 5 answers the following critical operational questions:
1. **Instrument**: What symbol is proposed to trade?
2. **Direction**: Is the trade BUY or SELL?
3. **Strategy Context**: Which strategy produced the opportunity, with what confidence and quality score?
4. **Entry**: What is the exact reference entry price?
5. **Invalidation Level**: Where is the structural invalidation price?
6. **Stop Loss**: What is the protective stop-loss price and distance in points?
7. **Take Profit**: What is the target take-profit price and distance in points?
8. **Risk/Reward**: Does the expected R:R ratio satisfy the configured minimum threshold ($\ge 1.50$)?
9. **Risk Budget**: What is the allowable cash risk based on account equity and configured risk percentage?
10. **Position Sizing**: What position volume satisfies the risk budget, normalized to broker volume step, min, and max?
11. **Broker Constraints**: Does the plan satisfy broker stops level, freeze level, and trading mode?
12. **Validity & Explainability**: Is the trade plan fully valid? If rejected, exactly which gate failed and why?
13. **Expiration**: When does the trade plan expire?

### Strict Safety Barrier
**PHASE 5 DOES NOT EXECUTE TRADES.**
The system operates exclusively in `MONITOR_ONLY` mode.
`CCapabilities::can_trade` remains hard-locked to `false`.
`STradePlan::execution_authorized` is permanently `false`.
The output terminates at `TRADE_PLAN_VALID` (Dry-Run Only) or `TRADE_PLAN_REJECTED` and halts.

---

## 2. Target Architecture & Pipeline

Phase 5 extends the deterministic hierarchy without modifying or bypassing previous phases:

```
RAW MARKET DATA (Phase 1)
       │ (Tick and Bar Data: M1, M5, M15, H1, H4, D1)
       ▼
MARKET FEATURES & REGIME (Phase 3)
       │ (ATR Volatility, Structure, Trend, Momentum, Regime Classification)
       ▼
SIGNAL CANDIDATE (Phase 3)
       │ (Confluence scoring, evidence, conflict detection)
       ▼
STRATEGY DECISION ENGINE (Phase 4)
       │ (Confluence scoring model, multi-timeframe alignment)
       ▼
STRATEGY VALIDATION (Phase 4)
       │ (9 Multi-Gate Quality Verification)
       ▼
APPROVED STRATEGY CANDIDATE
       │
       ▼
TRADE PLAN BUILDER (Phase 5)
       │ 1. Entry price computation
       │ 2. ATR & structural swing invalidation SL computation
       │ 3. Reward:Risk TP computation
       │ 4. Reuses canonical Phase 2E RiskEngine
       │ 5. Reuses canonical Phase 2E PositionSizer
       ▼
14-GATE TRADE PLAN VALIDATOR (Phase 5)
       │ Gates 1-14: Decision, Data, Direction, Entry, SL, TP, RR,
       │             Spread, Broker, Risk, Sizing, Expiry, Duplicate, Safety
       ▼
[TRADE_PLAN_VALID]  or  [TRADE_PLAN_REJECTED]
       │
       ▼
EXECUTION BOUNDARY (HARD LOCK)
(can_trade == false, execution_authorized == false -> STOP)
```

---

## 3. Trade Plan Contract (`STradePlan`)

The complete data contract is defined in [`Strategy/TradePlanTypes.mqh`](file:///c:/Users/biduo/Downloads/Forex%20Bot/mt5/ATG_TradingEngine/Strategy/TradePlanTypes.mqh).

### Data Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| `plan_id` | `ulong` | Unique incremental trade plan identifier |
| `symbol` | `string` | Broker instrument name (e.g., `EURUSDm`, `BTCUSDm`) |
| `strategy_id` | `string` | Strategy identifier (`"ATG_TREND_CONTINUATION"`) |
| `strategy_version` | `string` | Semantic strategy version (`"1.0.0"`) |
| `source_decision_id` | `ulong` | Reference ID linking back to the Phase 4 strategy decision |
| `direction` | `ENUM_ATG_TRADE_DIRECTION` | `ATG_DIRECTION_BUY` or `ATG_DIRECTION_SELL` |
| `primary_timeframe` | `ENUM_TIMEFRAMES` | Primary setup timeframe (`PERIOD_M15`) |
| `creation_time` | `datetime` | Local engine creation timestamp |
| `source_bar_time` | `datetime` | Closed bar timestamp from which setup was derived |
| `expiration_time` | `datetime` | Expiration timestamp ($creation + plan\_expiry\_sec$) |
| `plan_status` | `ENUM_TRADE_PLAN_STATUS` | `TRADE_PLAN_PENDING`, `TRADE_PLAN_VALID`, `TRADE_PLAN_REJECTED`, `TRADE_PLAN_INSUFFICIENT_DATA`, `TRADE_PLAN_EXPIRED` |
| `entry_price` | `double` | Target entry price (Ask for BUY, Bid for SELL) |
| `stop_loss` | `double` | Protective stop loss price |
| `take_profit` | `double` | Target profit price |
| `invalidation_price` | `double` | Structural swing level invalidating the thesis |
| `risk_distance_price`| `double` | Stop distance in quote currency |
| `risk_distance_points`| `double` | Stop distance in points |
| `reward_distance_price`| `double` | Take profit distance in quote currency |
| `reward_distance_points`| `double` | Take profit distance in points |
| `risk_reward_ratio` | `double` | Ratio of reward points to risk points |
| `min_reward_risk` | `double` | Configured minimum required R:R ratio ($1.50$) |
| `account_equity` | `double` | Account equity captured from broker at planning time |
| `risk_percent` | `double` | Configured risk budget percent ($1.00\%$) |
| `risk_money` | `double` | Allowed cash loss ($equity \times risk\_percent / 100$) |
| `calculated_volume` | `double` | Unrounded theoretical lot volume |
| `normalized_volume` | `double` | Broker-normalized volume (rounded to step, clamped to min/max) |
| `volume_min` | `double` | Broker minimum allowable volume |
| `volume_max` | `double` | Broker maximum allowable volume |
| `volume_step` | `double` | Broker volume increment step |
| `point_size` | `double` | Symbol point value |
| `tick_size` | `double` | Symbol tick size |
| `tick_value` | `double` | Tick value per standard lot |
| `spread_at_planning`| `int` | Real-time spread in points |
| `stops_level` | `int` | Broker minimum stop level in points |
| `freeze_level` | `int` | Broker freeze distance in points |
| `expected_loss` | `double` | Estimated loss in deposit currency if SL hit |
| `expected_reward` | `double` | Estimated profit in deposit currency if TP hit |
| `strategy_confidence`| `double` | Strategy confidence ($0.0$ to $1.0$) |
| `strategy_quality` | `double` | Strategy quality score ($0.0$ to $1.0$) |
| `regime` | `ENUM_ATG_MARKET_REGIME` | Primary market regime |
| `supporting_evidence`| `string` | Narrative explanation of strategy confluence |
| `rejection_reason` | `ENUM_PLAN_REJECTION_REASON` | Programmatic failure code |
| `rejection_detail` | `string` | Human-readable explanation of failed gate |
| `validation_flags` | `uint` | Bitmask tracking which of the 14 gates passed |
| `candidate_only` | `bool` | Permanently `true` |
| `execution_disabled`| `bool` | Permanently `true` |
| `execution_authorized`| `bool` | Permanently `false` (HARD SAFETY LOCK) |
| `formatted_plan` | `string` | Full human-readable audit text block |

---

## 4. Entry Model

The initial strategy `ATG_TREND_CONTINUATION` uses a deterministic market-referenced entry model:
- **BUY Setup**: Entry is taken at the current Ask price:
  $$Entry_{BUY} = \text{NormalizeDouble}(Tick.Ask, \text{Digits})$$
- **SELL Setup**: Entry is taken at the current Bid price:
  $$Entry_{SELL} = \text{NormalizeDouble}(Tick.Bid, \text{Digits})$$

The entry model is strictly referenced against the currently closed M15 bar state and live broker ticks. It forbids unclosed/future data.

---

## 5. Stop Loss Model

The SL model uses a hierarchical defense mechanism combining volatility and market structure:

1. **ATR Base Distance**:
   Calculated using M15 ATR (with fallback to H1 ATR if M15 is temporarily unavailable):
   $$SL_{DistancePoints} = ATR_{Points} \times Multiplier_{SL}$$
   Default multiplier: $2.0\times$.

2. **Market Structure Protection**:
   - **BUY**: Validated against `recent_swing_low` from M15 feature analysis. If a swing low exists below entry, structural invalidation is:
     $$Level_{Invalidation} = SwingLow - (5.0 \times Point)$$
     If $Level_{Invalidation}$ is further away than the ATR level, it is selected to ensure structural protection.
   - **SELL**: Validated against `recent_swing_high`. Structural invalidation is:
     $$Level_{Invalidation} = SwingHigh + (5.0 \times Point)$$
     If $Level_{Invalidation}$ is further away than the ATR level, it is selected.

3. **Directional Boundary Protection**:
   - For BUY: $SL < Entry$ strictly enforced.
   - For SELL: $SL > Entry$ strictly enforced.
   - Zero-distance and negative-distance stops are strictly rejected.

4. **Broker Stop Level Compliance**:
   $$SL_{DistancePoints} \ge StopsLevel_{Broker}$$
   If the stop is closer than the broker's minimum stop level, the plan is rejected.

---

## 6. Take Profit & Risk/Reward Model

1. **TP Placement**:
   Derived from the calculated SL distance and the configured target reward:risk ratio:
   $$TP_{DistancePoints} = SL_{DistancePoints} \times Multiplier_{TP}$$
   Default multiplier: $2.0\times$.
   - **BUY**: $TP = NormalizeDouble(Entry + TP_{DistancePoints} \times Point, Digits)$
   - **SELL**: $TP = NormalizeDouble(Entry - TP_{DistancePoints} \times Point, Digits)$

2. **Risk:Reward Verification**:
   $$R:R = \frac{TP_{DistancePoints}}{SL_{DistancePoints}}$$
   - Must satisfy $R:R \ge MinRewardRisk$ (Configured default: $1.50$).
   - If below minimum, the plan is rejected with `PLAN_REJECT_NEGATIVE_RR`.

---

## 7. Risk Engine Integration

Phase 5 reuses the canonical Phase 2E [`Execution/RiskEngine.mqh`](file:///c:/Users/biduo/Downloads/Forex%20Bot/mt5/ATG_TradingEngine/Execution/RiskEngine.mqh):
- TradePlanner queries `m_risk_engine.Calculate(symbol, entry, stop_loss, risk_pct, risk_result)`.
- Validates account equity ($> 0$).
- Enforces configured risk budget ($1.00\%$ of equity, maximum allowed $2.00\%$).
- Calculates precise risk money:
  $$\text{Risk Money} = Equity \times \frac{\text{Risk Percent}}{100}$$

---

## 8. Position Sizing Integration

Phase 5 reuses the canonical Phase 2E [`Execution/PositionSizer.mqh`](file:///c:/Users/biduo/Downloads/Forex%20Bot/mt5/ATG_TradingEngine/Execution/PositionSizer.mqh):
- Computes loss per standard lot using `OrderCalcProfit` or tick economics:
  $$\text{Loss Per Lot} = \frac{|Entry - SL|}{TickSize} \times TickValue$$
- Calculates raw volume:
  $$\text{Raw Volume} = \frac{\text{Risk Money}}{\text{Loss Per Lot}}$$
- Applies broker volume normalization:
  - Rounds down to nearest `volume_step`:
    $$\text{Volume} = \text{MathFloor}\left(\frac{\text{Raw Volume}}{\text{Step}}\right) \times \text{Step}$$
  - Clamps to `[volume_min, volume_max]`.
  - Rejects if final volume $< volume\_min$ with `PLAN_REJECT_ZERO_VOLUME`.

---

## 9. 14-Gate Validation Pipeline

Every Trade Plan must pass all 14 gates before reaching `TRADE_PLAN_VALID`:

| Gate | Name | Verification |
| :---: | :--- | :--- |
| **1** | `SOURCE_DECISION_VALID` | Phase 4 decision must be approved (`is_approved == true`, `status == STRATEGY_APPROVED`). |
| **2** | `DATA_VALID` | Symbol exists, point size $> 0$, tick size $> 0$, tick value $> 0$, MTF features ready. |
| **3** | `DIRECTION_VALID` | Direction must be explicitly `BUY` or `SELL` (never `NONE`). |
| **4** | `ENTRY_VALID` | Valid live tick price obtained; entry price $> 0$. |
| **5** | `SL_VALID` | BUY SL $<$ Entry; SELL SL $>$ Entry; stop distance $> 0$; $\ge$ broker stops level. |
| **6** | `TP_VALID` | BUY TP $>$ Entry; SELL TP $<$ Entry; reward distance $> 0$; $\ge$ broker stops level. |
| **7** | `RR_VALID` | Computed R:R ratio $\ge$ configured minimum ($1.50$). |
| **8** | `SPREAD_VALID` | Spread at planning time $\le$ max tolerance ($40$ pts); spread not invalidated since decision. |
| **9** | `BROKER_CONSTRAINTS_VALID`| Broker trade mode enabled; stops level respected; freeze level respected; volume rules valid. |
| **10**| `RISK_VALID` | RiskEngine approves budget; equity $> 0$; risk within limits. |
| **11**| `POSITION_SIZE_VALID` | PositionSizer calculates valid lot size; normalized volume $\ge$ broker minimum. |
| **12**| `EXPIRATION_VALID` | Current time within validity window ($now < creation\_time + plan\_expiry\_sec$). |
| **13**| `DUPLICATE_CHECK` | Suppresses redundant plan generation on the same closed bar timestamp. |
| **14**| `EXECUTION_SAFETY_CHECK` | `execution_authorized = false` hard-locked; `candidate_only = true`; `can_trade = false`. |

---

## 10. Centralized Configuration

All tunable parameters are centralized in [`Config/Config.mqh`](file:///c:/Users/biduo/Downloads/Forex%20Bot/mt5/ATG_TradingEngine/Config/Config.mqh):

```mql5
// Versioning
ea_version           = "0.5.0";
config_version       = "1.8.0";

// Phase 5 Trade Planning Parameters
risk_percent         = 1.0;     // 1.0% equity risk per trade
min_reward_risk      = 1.5;     // 1.50 minimum R:R
sl_atr_multiplier    = 2.0;     // 2.0x ATR for Stop Loss
tp_rr_multiplier     = 2.0;     // 2.0x R:R for Take Profit
max_spread_tolerance = 40;      // 40 points max spread
plan_expiry_sec      = 1800;    // 30 minutes validity window
entry_buffer_points  = 0.0;
```

---

## 11. Structured Diagnostics

The engine emits standardized diagnostic events:
- `TRADE_PLAN_EVALUATION`: Start of evaluation for a qualified candidate.
- `TRADE_PLAN_CREATED`: Plan successfully built.
- `TRADE_PLAN_VALID`: All 14 gates verified; plan ready (DRY-RUN ONLY).
- `TRADE_PLAN_REJECTED`: Specific gate failure and detail.
- `TRADE_PLAN_EXPIRED`: Plan passed expiration horizon.
- `TRADE_PLAN_DUPLICATE`: Repeated closed-bar evaluation suppressed.
- `TRADE_PLAN_RISK_REJECTED`: Risk budget violation.
- `TRADE_PLAN_BROKER_REJECTED`: Broker constraint violation.
- `TRADE_PLAN_RR_REJECTED`: Reward:risk below minimum.
- `TRADE_PLAN_SAFETY_BLOCKED`: Live execution attempt blocked.

---

## 12. Verification & Test Suite

The test suite in [`Tests/Phase5Tests.mqh`](file:///c:/Users/biduo/Downloads/Forex%20Bot/mt5/ATG_TradingEngine/Tests/Phase5Tests.mqh) executes 20 automated unit tests during engine initialization:

1. **Valid Bullish Trade Plan**: Verifies full plan generation for BUY setups. (**PASS**)
2. **Valid Bearish Trade Plan**: Verifies full plan generation for SELL setups. (**PASS**)
3. **Invalid BUY SL Above Entry**: Detects and rejects illegal SL placement for BUY. (**PASS**)
4. **Invalid SELL SL Below Entry**: Detects and rejects illegal SL placement for SELL. (**PASS**)
5. **Invalid TP Direction**: Rejects inverted TP levels. (**PASS**)
6. **RR Below Minimum**: Rejects setups with R:R $< 1.50$. (**PASS**)
7. **Excessive Spread**: Rejects setups when spread exceeds tolerance. (**PASS**)
8. **Broker Stop-Level Violation**: Rejects stops closer than broker minimum. (**PASS**)
9. **Invalid Tick/Point Data**: Detects zero/negative tick or point economics. (**PASS**)
10. **Insufficient Market Data**: Rejects when market features are unready. (**PASS**)
11. **Risk Budget Calculation**: Validates $equity \times risk\_pct$ arithmetic. (**PASS**)
12. **Position Sizing Logic**: Validates volume calculation from stop distance. (**PASS**)
13. **Volume Step Normalization**: Confirms proper lot rounding down to step. (**PASS**)
14. **Volume Below Broker Minimum**: Rejects volumes below broker threshold. (**PASS**)
15. **Volume Above Broker Maximum**: Rejects volumes exceeding broker limit. (**PASS**)
16. **Zero Stop Distance**: Rejects zero-distance stops. (**PASS**)
17. **Duplicate Trade Plan Suppression**: Verifies closed-bar duplicate blocking. (**PASS**)
18. **Expired Trade Plan**: Detects plans exceeding validity window. (**PASS**)
19. **Strategy Rejection Propagation**: Confirms unapproved candidates are blocked at Gate 1. (**PASS**)
20. **Execution Safety Hard Lock**: Confirms `can_trade = false` and `execution_authorized = false`. (**PASS**)

---

## 13. Safety Audit & Search

A complete repository grep confirms:
- `OrderSend`: **0 active calls**
- `CTrade.Buy`: **0 calls**
- `CTrade.Sell`: **0 calls**
- `PositionOpen`: **0 calls**
- `can_trade`: **Hard-locked to `false`**
- `MONITOR_ONLY`: **`true`**

---

## 14. Known Limitations & Future Boundary

1. **Execution Boundary**: Phase 5 produces Trade Plans only. It does not send order requests to brokers. Future Phase 6 will implement controlled order submission when explicitly enabled.
2. **Strategy Count**: Currently implemented for `ATG_TREND_CONTINUATION`. Additional strategies (mean reversion, breakout) can plug into the same 14-gate trade planning architecture.
3. **News Filtering**: Economic calendar news volatility filters are scheduled for a future intelligence phase.
