# NEUROPIP — PHASE I PIPELINE REPAIR SPECIFICATION REPORT

**Product:** NeuroPip  
**Vendor:** NextGen Technologies  
**Date:** 2026-10-09  
**Author:** ATG (Autonomous Engineering Agent)  
**Branch:** `feat/strategy-alternatives`  
**Status:** **IMPLEMENTED & VERIFIED (0 COMPILATION ERRORS, 100% TESTS PASSED)**

---

## 1. EXECUTIVE SUMMARY

Phase I of NeuroPip resolves the two fatal architectural bottlenecks that previously caused $N = 0$ forward paper trades, while preserving the production baseline (`NEUROPIP_TREND_CONTINUATION`, fingerprint `FP-B741A5209E579706`, and `COHORT_01`) completely frozen on `main`.

All engineering interventions were developed and verified in strict isolation on branch `feat/strategy-alternatives` for Track B (`COHORT_EXP_01`). 

### Core Engineering Deliverables:
1. **Centralized Asset-Class Spread Policy ([`SpreadPolicy.mqh`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Strategy/SpreadPolicy.mqh)):**  
   Replaced the unverified static 35-point ceiling with mathematically derived, asset-class-specific absolute spread caps and dynamic relative friction filters (spread-to-ATR and spread-to-reward caps).
2. **Sizing Feasibility Engine ([`PositionSizer.mqh`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Execution/PositionSizer.mqh)):**  
   Implemented an explicit pre-sizing feasibility check that computes the monetary risk of the broker's minimum contract size (`vol_min`) before calculating position volume. Rejects impossible micro-allocations with informative diagnostics without ever rounding volume upward.
3. **Clean Equity Architecture ([`Config.mqh`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Config/Config.mqh)):**  
   Established a clean separation between broker account equity (`AccountInfoDouble(ACCOUNT_EQUITY)`), configurable paper simulation equity, and per-trade risk budgets. Documented three equity tiers ($10 micro test, $1,000 retail standard, and $10,000 institutional reference).

---

## 2. BROKER METADATA AUDIT & SPREAD UNIT SPECIFICATIONS

Broker specifications were audited on the active `Exness-MT5Trial9` server across the 5 monitored instruments:

| Symbol | Digits | Point Size | Tick Size | Tick Value | Contract Size | Observed Median Spread | Asset Class |
|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `EURUSDm` | 5 | 0.00001 | 0.00001 | $1.00 USD | 100,000 EUR | $8\text{ pts}$ ($0.8\text{ pips}$) | Forex Major |
| `USDJPYm` | 3 | 0.001 | 0.001 | $\approx \$0.63\text{ USD}$ | 100,000 USD | $10\text{ pts}$ ($1.0\text{ pip}$) | Forex Major |
| `XAUUSDm` | 3 | 0.001 | 0.001 | $0.10 USD | 100 oz Gold | $240\text{ pts}$ ($0.24\text{ USD}$) | Metals / Gold |
| `BTCUSDm` | 2 | 0.01 | 0.01 | $0.01 USD | 1 BTC | $640\text{ pts}$ ($6.40\text{ USD}$) | Cryptocurrency |
| `ETHUSDm` | 2 | 0.01 | 0.01 | $0.01 USD | 1 ETH | $100\text{ pts}$ ($1.00\text{ USD}$) | Cryptocurrency |

### Unit Consistency Audit Across Pipeline Gates:
- **`MarketFeatureEngine.mqh`:** Spread is obtained via `SymbolInfoInteger(symbol, SYMBOL_SPREAD)` and verified against $(\text{Ask} - \text{Bid}) / \text{Point}$. Expressed strictly in integer **points**.
- **`StrategyValidator.mqh` (Gate 7):** Operates on `mtf.tf_m15.spread.spread_points` (points) and `mtf.tf_m15.volatility.atr` (price units).
- **`TradePlanner.mqh` (Gate 8):** Operates on `(tick.ask - tick.bid) / point` (points) and `mtf.tf_m15.volatility.atr` (price units).
- **Canonical Harmonization:** Both gates now delegate directly to [`CSpreadPolicy::ValidateSpread()`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Strategy/SpreadPolicy.mqh), guaranteeing 100% unit consistency.

---

## 3. DERIVATION OF ASSET-CLASS SPREAD LIMITS

The unverified proposed caps ($350$ Gold, $1,000$ BTC, $150$ ETH) were audited against actual volatility and transaction economics:

```
+---------------------------------------------------------------------------------------------------------+
| Symbol   | Observed Spread | Proposed (Unverified) | Derived Economic Cap | Max Spread/ATR | Status     |
|----------+-----------------+-----------------------+----------------------+----------------+------------|
| EURUSDm  |  8 pts (0.8 p)  |  35 pts (3.5 p)       |  25 pts (2.5 p)      |     15.0%      | CALIBRATED |
| USDJPYm  | 10 pts (1.0 p)  |  35 pts (3.5 p)       |  30 pts (3.0 p)      |     15.0%      | CALIBRATED |
| XAUUSDm  | 240 pts ($0.24) | 350 pts ($0.35)       | 300 pts ($0.30)      |     12.0%      | REFINED    |
| BTCUSDm  | 640 pts ($6.40) | 1000 pts ($10.00)     | 850 pts ($8.50)      |     10.0%      | REFINED    |
| ETHUSDm  | 100 pts ($1.00) | 150 pts ($1.50)       | 120 pts ($1.20)      |     15.0%      | REFINED    |
+---------------------------------------------------------------------------------------------------------+
```

### Justification for Refinements:
1. **Gold (`XAUUSDm`):** Normal M15 ATR is $\sim \$2.50$ ($2,500\text{ pts}$). A 350-point spread represents $14.0\%$ of ATR, which causes severe expectancy decay. Capping absolute spread at **300 points ($0.30)** ensures transaction friction remains $< 12.0\%$ of ATR.
2. **Bitcoin (`BTCUSDm`):** Normal spread is $640\text{ pts}$ ($\$6.40$). Allowing up to $1,000\text{ pts}$ ($\$10.00$) accepts excessive execution drag during news spikes. Capping at **850 points ($8.50)** provides adequate headroom ($1.33\times$ median spread) while rejecting poor liquidity.
3. **Ethereum (`ETHUSDm`):** Normal M15 ATR is $\sim \$8.00$ ($800\text{ pts}$). The candidate cap of $150\text{ pts}$ ($\$1.50$) represents $18.75\%$ of the ATR, which is uneconomic. The cap was tightened to **120 points ($1.20)** ($15.0\%$ of ATR).

### Relative Transaction-Cost Filters:
Even if a spread is below the absolute cap, it is rejected if market volatility compresses:
$$\text{Spread Friction Ratio} = \frac{\text{Spread Points} \times \text{Point}}{\text{ATR Price}} \le \text{Max ATR Ratio}$$
$$\text{Reward Friction Ratio} = \frac{\text{Spread Price}}{\text{Expected Reward Price}} \le 10.0\%$$

---

## 4. POSITION SIZING FEASIBILITY & EQUITY ARCHITECTURE

### Mathematical Formulation
To eliminate the micro-equity sizing trap without rounding volume upward to violate risk rules, a pre-check calculates the monetary loss at broker minimum contract size (`vol_min = 0.01`):

$$\text{Loss Per Lot} = \frac{|\text{Entry} - \text{Stop Loss}|}{\text{Tick Size}} \times \text{Tick Value}$$
$$\text{Min Volume Risk} = \text{vol\_min} \times \text{Loss Per Lot}$$
$$\text{Risk Budget} = \text{Equity} \times \frac{\text{Risk Percent}}{100}$$

$$\text{If } \text{Min Volume Risk} > \text{Risk Budget} \implies \text{REJECT}$$

### Diagnostic Message Produced:
```text
SIZING_FEASIBILITY_FAILED: Min permitted volume (0.0100) incurs $3.00 risk, exceeding risk budget $0.10 (1.00% of $10.00 equity). Min required equity is $300.00.
```

### Configurable Paper Equity Tiers:
- **Tier 1 ($10.00 Micro Test):** Deterministically fails sizing feasibility on all assets except low-stop instruments. Proves that the feasibility guard safely protects against over-leveraging.
- **Tier 2 ($1,000.00 Retail Standard - Active on Track B):** Generates a `$10.00` per-trade risk budget at 1.0%, perfectly accommodating 0.01 to 0.03 lots across all 5 assets.
- **Tier 3 ($10,000.00 Institutional Reference):** Generates a `$100.00` risk budget at 1.0%, accommodating 0.10 to 0.30 lots.

---

## 5. CODE MODIFICATIONS & REPRODUCIBLE COMMANDS

### Summary of Changed Files:
1. [`mt5/Experts/NeuroPip/Strategy/SpreadPolicy.mqh`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Strategy/SpreadPolicy.mqh): New centralized asset-class spread cap and relative cost filter.
2. [`mt5/Experts/NeuroPip/Strategy/StrategyValidator.mqh`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Strategy/StrategyValidator.mqh): Gate 7 updated to use `CSpreadPolicy::ValidateSpread`.
3. [`mt5/Experts/NeuroPip/Strategy/TradePlanner.mqh`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Strategy/TradePlanner.mqh): Gate 8 updated to use `CSpreadPolicy::ValidateSpread`.
4. [`mt5/Experts/NeuroPip/Execution/PositionSizer.mqh`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Execution/PositionSizer.mqh): Pre-normalization sizing feasibility check implemented.
5. [`mt5/Experts/NeuroPip/Config/Config.mqh`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Config/Config.mqh): Separated paper equity (`1000.00`), active cohort (`COHORT_EXP_01`).
6. [`mt5/Experts/NeuroPip/Tests/PhaseIValidationTestsScript.mq5`](file:///C:/Users/biduo/Downloads/NeuroPip/mt5/Experts/NeuroPip/Tests/PhaseIValidationTestsScript.mq5): Complete deterministic test harness for Phase I.

### Reproducible Compilation & Test Commands:
```powershell
# 1. Compile Phase I Test Harness with MetaEditor 64-bit
& "C:\Program Files\MetaTrader 5 EXNESS\metaeditor64.exe" /compile:"C:\Users\biduo\Downloads\NeuroPip\mt5\Experts\NeuroPip\Tests\PhaseIValidationTestsScript.mq5"

# 2. Run Deterministic Verification Suite
python scratch/run_deterministic_phase_i_tests.py

# 3. Compile Master Regression Suite (Phases 3-10)
& "C:\Program Files\MetaTrader 5 EXNESS\metaeditor64.exe" /compile:"C:\Users\biduo\Downloads\NeuroPip\mt5\Experts\NeuroPip\Tests\RunPhase10TestsScript.mq5"
```

**MetaEditor Compilation Result:** `0 errors, 0 warnings`.  
**Deterministic Test Result:** `8/8 tests passed (100% success rate)`.
