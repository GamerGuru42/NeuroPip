# NeuroPip - Cloud API Spec

## 1. Role of the Cloud
ATG Cloud handles telemetry, analytics, license validation, and user configuration. It is never part of the synchronous trade execution loop.

## 2. Telemetry & Communications
- **Asynchronous Batching**: The EA queues JSON telemetry payloads locally and dispatches them via `WebRequest` during the Periodic Tasks loop.
- **Idempotent Delivery**: All payloads must have unique IDs to prevent duplicate logging on retries.

## 3. Resilience & Disconnection
If the Cloud becomes unreachable:
1. Existing positions remain protected (Broker SL/TP).
2. Local risk controls continue to manage trailing stops or timed exits.
3. Telemetry queues to memory/disk.
4. After a configurable timeout, the EA enters a restricted/safe mode where no new positions are opened until license validation is restored.

## 4. User Experience (Dashboard)
The UI presents the telemetry to answer:
- Why did ATG trade?
- Why did ATG not trade?
- Why is ATG waiting?
- Why was this position size selected?
- Why was this position closed?
- Why is the system in Safe Mode?

*Note: Proprietary formulas and raw indicators are obfuscated from the user view.*
