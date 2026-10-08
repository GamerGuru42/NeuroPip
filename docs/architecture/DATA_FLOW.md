# ATG Trading Engine - Data Flow

## 1. Local Execution Hot Path
The trade decision process is entirely local and synchronous. It must **never** block waiting for a WebRequest or cloud decision.

**Flow:**
`Market Data -> Local Analysis -> Local Forecast -> Local Strategy -> Local Risk -> Local Execution -> Exness`

1. **Market Data Ingestion**: Ticks and bars update local state.
2. **Analysis & Forecast**: FeatureEngine updates metrics; RegimeEngine and ForecastEngine assess market structure.
3. **Strategy & Signal**: StrategyEngine evaluates conditions; SignalEngine creates a localized candidate signal.
4. **Risk & Sizing**: RiskEngine approves/rejects; PositionSizing calculates volume.
5. **Execution**: ExecutionEngine validates spread, sends the order.
6. **Reconciliation**: `OnTradeTransaction()` confirms the deal and logs the position.

## 2. Telemetry and Cloud Synchronization (Asynchronous)
- All decisions, state changes, and trade executions emit events.
- Events are queued locally in memory or local disk buffer.
- The `Telemetry` module batches and transmits these events via `WebRequest` in the Periodic Tasks loop.
- If the transmission fails, the queue is preserved and retried later.

## 3. Account Connection Flow
1. User logs into MT5 directly using their broker credentials (Exness).
2. The EA is launched inside MT5.
3. The EA identifies the connected account/server.
4. The EA securely authenticates and binds to ATG Licensing via HTTPS WebRequest.
5. The ATG Dashboard updates to display the connection status.
- **Rule**: Never store or transmit broker master passwords to the ATG Cloud.
