# ATG Trading Engine - Security Spec

## 1. System Security
- **Authentication**: All API communication between EA and Cloud must be authenticated via secure tokens over HTTPS.
- **No Credential Storage**: The system must NOT store or transmit the user's Exness Master Password. 
- **Licensing**: EA requires a heartbeat license validation. Device binding restricts EA copying.
- **Audit Logging**: All configuration changes and state transitions are immutable and logged.
- **Emergency Controls**: The Cloud can issue emergency license revocation or an emergency trading disable command (handled asynchronously).

## 2. AI Policy
AI modules in the Cloud may analyze performance, suggest parameter changes, detect anomalies, or explain decisions.

**AI must NOT:**
- Automatically increase live risk.
- Remove Stop Losses or bypass circuit breakers.
- Deploy untested strategies.
- Modify core live risk rules without explicit user/admin approval.
- Disable emergency controls.

Any AI-driven strategy modification must undergo the strict Research Pipeline (Backtest -> OOS -> Walk-Forward -> Robustness -> Demo -> Approval).
