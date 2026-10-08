# NeuroPip Expert Advisor Source Directory

**Destination Module:** `mt5/Experts/NeuroPip/`  
**Target Environment:** MetaTrader 5 (MQL5 64-bit)  
**Vendor:** NextGen Technologies

## Overview

This directory is designated as the official repository location for the **NeuroPip** MQL5 Expert Advisor source code, to be populated during **Phase C source migration**.

## Target Module Structure

Following the Phase A architectural audit, the core 29 MQL5 files will be organized into the following submodules:

- **`NeuroPip.mq5`**: Main Expert Advisor entry point (`OnInit`, `OnTick`, `OnDeinit`, `OnChartEvent`).
- **`Analytics/`**: Trade metrics, drawdown tracking, forward milestone evaluation.
- **`Config/`**: Immutable system configuration, symbol parameters, and fingerprint verification (`FP-B741A5209E579706`).
- **`Diagnostics/`**: Telemetry reporting, log formatting, heartbeat generation, and diagnostic alerts.
- **`Execution/`**: `CExecutionGuard`, order checking, paper execution engine, and hard-lock enforcement.
- **`MarketData/`**: Multi-symbol feed ingestion, spread filters, and tick validation.
- **`Regime/`**: Multi-timeframe trend and volatility regime classification.
- **`Risk/`**: 1.0% equity risk budgeting, 2.0x ATR stop loss sizing, and draw-down limits.
- **`Strategy/`**: Trend continuation strategy logic, entry/exit criteria, and candidate scoring.
- **`Storage/`**: Non-custodial persistent audit logging and trade store serialization.
- **`Telemetry/`**: Cloud/local telemetry schema interfaces and event publishers.

## Phase B Status

*Source migration scheduled for Phase C. No legacy source files or compiled binaries (`.ex5`) are present during Phase B.*
