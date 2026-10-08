# NeuroPip - Execution State Machine

## 1. Overview
Trade execution follows a strict lifecycle. We do not assume `OrderSend(true)` means success. Idempotency and reconciliation via `OnTradeTransaction()` are mandatory.

## 2. Primary States
- `SIGNAL_CREATED`: SignalEngine emits a valid entry candidate.
- `RISK_APPROVED`: RiskEngine verifies constraints and PortfolioRisk allows it.
- `ORDER_PREPARED`: PositionSizing sets the volume, SL/TP are calculated.
- `ORDER_CHECKED`: `OrderCheck()` verifies margin and broker rules locally.
- `ORDER_SUBMITTED`: `OrderSend()` is called and an async ticket/response is awaited.
- `ORDER_ACCEPTED`: Broker server acknowledges the order.
- `POSITION_OPENED`: Reconciled deal from broker; position is live.
- `POSITION_MODIFIED`: SL/TP adjusted based on trade management rules.
- `POSITION_CLOSED`: Position is flattened either by EA or broker stop.

## 3. Failure States
- `REJECTED`: Pre-submission failure (e.g., failed Risk or `OrderCheck`).
- `ERROR`: Server returned an error on `OrderSend`.
- `TIMEOUT`: No response received within the expected window.
- `UNKNOWN`: Connectivity lost mid-transaction; requires reconciliation.
- `RECONCILIATION_REQUIRED`: System must sync state with broker before taking further action.

## 4. Protective Orders Policy
- **Mandatory Hard Stops**: Where broker rules permit, every new position must have a hard broker-side SL attached at creation.
- **Take Profit**: Attached where dictated by strategy.
- **No Virtual Stops Only**: Virtual stops must never be the sole protection for a live position.
