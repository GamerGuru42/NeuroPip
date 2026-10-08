# NeuroPip - Strategy & Signal Engine Spec

## 1. Strategy Engine
The Strategy Engine evaluates specific, testable edge-cases in the market. Each strategy must explicitly declare the Market Regimes under which it is permitted to operate.

### Initial Strategies
1. **Trend Pullback**: Entering established trends on retracements.
2. **Momentum Continuation**: Entering on strong directional impulses.
3. **Breakout**: Entering upon clearing established consolidation zones.
4. **Mean Reversion**: Fading extremes back to value areas (requires RANGE regime).
5. **Session-Based**: Exploiting specific liquidity windows (e.g., London open, NY overlap).

## 2. Signal Engine
The Signal Engine consumes Strategy outputs and determines the final viability of an execution.

### Signal Quality Scoring
Quality is determined by combining:
- Forecast confidence & Regime alignment
- Market structure clarity & Momentum
- Current Spread & Volatility conditions
- Entry quality & Higher-timeframe confirmation
- Portfolio exposure overlap

### Signal States
- `REJECT`: Fails quality threshold or violates a core rule.
- `WATCH`: Close to threshold, warrants high-frequency monitoring.
- `QUALIFIED`: Meets all baseline criteria; cleared for execution if Risk approves.
- `HIGH_CONVICTION`: Exceptional alignment across all vectors; may warrant increased risk allocation.
