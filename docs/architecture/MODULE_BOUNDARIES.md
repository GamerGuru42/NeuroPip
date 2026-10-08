# NeuroPip - Module Boundaries

The MT5 EA is strictly modular. The main EA file orchestrates these independent modules rather than containing implementation details.

## Core Modules
1. **Core**: Overall orchestrator, event dispatcher, state initialization.
2. **Configuration**: Parses, validates, and stores system settings and parameters.
3. **MarketData**: Dynamic discovery of symbols, ticking, bar aggregation, volume, and contract rules.
4. **FeatureEngine**: Calculates indicators, oscillators, and derived metrics from MarketData.
5. **RegimeEngine**: Classifies the current market state (Trend, Range, Volatility).
6. **ForecastEngine**: Generates a structured market assessment (bias, momentum, reversal risk).
7. **StrategyEngine**: Evaluates specific trading strategies (Trend Pullback, Breakout, etc.) against the forecast and regime.
8. **SignalEngine**: Combines strategy output with portfolio exposure and execution quality to produce final signal scores (REJECT, WATCH, QUALIFIED, HIGH_CONVICTION).
9. **RiskEngine**: Enforces global risk rules, daily limits, drawdown constraints, and emergency stops.
10. **PortfolioRisk**: Monitors cross-symbol correlation and total portfolio exposure.
11. **PositionSizing**: Calculates exact trade volumes based on equity, risk %, stop distance, and broker rules.
12. **ExecutionEngine**: Manages the order lifecycle (Check -> Send -> Verify).
13. **Reconciliation**: Verifies order state with `OnTradeTransaction()`, handling idempotency and duplicates.
14. **TradeJournal**: Records detailed trade context and outcomes.
15. **Telemetry**: Batches system events, decisions, and metrics for asynchronous cloud transmission.
16. **Security**: Handles EA licensing, heartbeat, configuration versioning, and environment verification.
17. **Diagnostics**: Tracks system health, latency, execution times, and resource usage.
18. **EmergencyControls**: Circuit breakers and safe-mode triggers.

## Module Interfaces Guidelines
- Modules communicate via well-defined structs or classes.
- Modules must not bypass the core orchestrator to invoke each other tightly, reducing circular dependencies.
