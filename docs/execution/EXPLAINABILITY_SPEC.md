# NeuroPip - Explainability Spec

## 1. Core Principle
The EA must emit structured, machine-readable reason codes and metrics. It must **not** generate natural-language explanations locally. The ATG Cloud translates these structures into plain English for the User Dashboard.

## 2. Reason Code Registry
A formal, exhaustive list of reason codes must govern every decision.

### Execution Reason Codes
- `SETUP_QUALIFIED_BUY`
- `SETUP_QUALIFIED_SELL`

### Rejection Reason Codes
- `SCORE_BELOW_THRESHOLD`
- `SPREAD_BLOWOUT`
- `VOLATILITY_TOO_HIGH` / `VOLATILITY_TOO_LOW`
- `PORTFOLIO_EXPOSURE` / `CORRELATION_LIMIT`
- `MARGIN_BUFFER_LOW`
- `DAILY_LOSS_LIMIT` / `DRAWDOWN_LIMIT`
- `REGIME_UNSUPPORTED`
- `ENTRY_NOT_CONFIRMED`
- `NEWS_RESTRICTION`
- `MARKET_CLOSED` / `SYMBOL_UNAVAILABLE`
- `EXECUTION_ERROR`
- `LICENSE_RESTRICTED`

## 3. Data Structures
**Trade Execution Payload Example:**
```json
{
  "symbol": "EURUSD",
  "decision": "TRADE",
  "direction": "BUY",
  "reason_code": "SETUP_QUALIFIED_BUY",
  "signal_score": 86,
  "regime": "TREND_UP",
  "strategy": "TREND_PULLBACK"
}
```

**Rejection Payload Example:**
```json
{
  "symbol": "XAUUSD",
  "decision": "NO_TRADE",
  "reason_code": "SPREAD_BLOWOUT"
}
```
