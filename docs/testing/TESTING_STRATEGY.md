# ATG Trading Engine - Testing Strategy

## 1. Research & Validation Pipeline
No strategy or logic update reaches live deployment without passing:
1. **Historical Backtest**: Baseline profitability and logic check.
2. **Out-of-Sample (OOS)**: Validation on unseen historical data.
3. **Walk-Forward Analysis**: Dynamic window testing for parameter decay.
4. **Robustness / Monte Carlo**: Randomizing trade sequences, slightly altering entries/exits.
5. **Stress Tests**: Simulating extreme spread, execution delay, slippage, market gaps, and news events.
6. **Demo Deployment**: Forward testing on an Exness demo environment.
7. **Controlled Live Deployment**: Small-size real-money validation.

## 2. Realistic Simulation Requirements
Testing must not optimize for superficial "total profit" or "win rate" metrics. It must account for:
- Spread costs and Commission
- Slippage and Execution Latency
- Minimum losing streaks and Drawdown duration

## 3. Development Testing
Each module (Core, Risk, Position Sizing, etc.) must be independently testable. Development cannot proceed to the next phase until the current phase compiles cleanly, runs without errors, and passes defined exit criteria.
