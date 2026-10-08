# ATG Trading Engine - System Architecture

## 1. Overview
ATG Trading Engine is a private automated trading platform designed for integration with Exness via MetaTrader 5 (MT5). The architecture is defined by a strict separation of concerns between deterministic local execution and cloud-based management.

## 2. System Topology
**ATG APP -> ATG CLOUD -> MT5 VPS -> ATG_TradingEngine.ex5 -> Exness -> Markets**

- **MT5 EA (ATG_TradingEngine.ex5)**: The deterministic local execution engine running on a VPS. Responsible for all market data ingestion, local analysis, risk management, and execution.
- **ATG Cloud**: Responsible for licensing, telemetry, analytics, explanations, notifications, configuration, and research support. The cloud is **NEVER** required for an individual trade execution decision.

## 3. Core Principles
- **Always Watching != Always Trading**: The system monitors eligible markets continuously but trades only when all stringent criteria are met. Objective is high-quality validated trade selection, not maximum trade frequency.
- **Local Execution First**: Critical trading, risk, and position-protection logic executes entirely within the MT5 EA.
- **Single Chart Monitoring**: The EA must be capable of monitoring multiple symbols from a single chart instance, eliminating the need to open a chart for every instrument.

## 4. Event Model
The system uses a high-resolution timer (e.g., `EventSetMillisecondTimer(100)`), but strictly limits computation to avoid CPU bottlenecks.

- **Fast Loop**: Account safety, open-position protection, latest tick state, spread checks, execution-sensitive monitoring.
- **New Tick**: Update market state, execution-sensitive changes.
- **New Bar**: Indicators, market structure, regime, forecast, strategy analysis.
- **Periodic Tasks**: Correlation, portfolio analysis, deeper market scanning, telemetry batching, maintenance.

## 5. Resilience
If the ATG Cloud fails:
- Existing positions remain protected by broker-side SL/TP.
- Local risk controls and position management continue.
- Telemetry is queued locally.
- New trade permissions may be disabled after a configurable timeout, entering restricted/safe mode.
