# NeuroPip - Market Intelligence Spec

## 1. Market Data Ingestion
The EA dynamically discovers and manages the symbol universe. Hard-coded symbol names are forbidden.

- **Configurable Universe**: The system accepts a baseline universe (e.g., EURUSD, XAUUSD, NAS100) and maps them to the actual broker strings.
- **Data Collection**: 
  - Real-time Bid/Ask and Spread tracking.
  - Tick and Volume data (where supported).
  - Bar aggregation for required timeframes.
  - Symbol Contract properties: tick size, tick value, point size, volume min/max/step, stop level, freeze level, margin requirements.

## 2. Market Modes
Every tracked symbol operates in one of three modes:
- `AUTO`: The engine analyzes and can execute trades.
- `WATCH`: The engine analyzes, forecasts, and logs data, but execution is blocked.
- `DISABLED`: The engine ignores the symbol completely to save CPU.
- **Hybrid Behavior**: Users can set favorites, while the system dynamically discovers other eligible markets and puts them in `WATCH` or `AUTO` based on configuration.

## 3. Regime Engine
Classifies the current state of the market to dictate which strategies are viable.

### Defined Regimes:
- `TREND_UP`: Clear higher highs and higher lows.
- `TREND_DOWN`: Clear lower highs and lower lows.
- `RANGE`: Mean-reverting, bound between defined support/resistance.
- `BREAKOUT_SETUP`: Coiling or consolidating near key levels.
- `HIGH_VOLATILITY`: Expanded ranges, fast price action.
- `LOW_VOLATILITY`: Compressed ranges, low participation.
- `CHAOTIC`: Unpredictable chop, failing structure.
- `ILLIQUID`: Poor pricing, massive spreads, lack of volume.
- `UNKNOWN`: Failsafe default. Must default to **NO TRADE**.
