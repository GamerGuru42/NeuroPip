# NeuroPip Runtime Monitoring & Health Infrastructure

**NextGen Technologies — Operational Reliability & Supervisor Framework**

## Overview

This directory provides runtime monitoring, process supervision, and health verification tools for the **NeuroPip** MetaTrader 5 trading engine.

## Planned Components (Phase C Migration)

- **`runtime_supervisor.py`**: Out-of-process supervisor daemon ensuring terminal uptime, chart attachment, and automated recovery without touching active trade states.
- **`health_check.py`**: Automated heartbeat and tick freshness verification across all watched trading symbols (`EURUSDm`, `USDJPYm`, `XAUUSDm`, `BTCUSDm`, `ETHUSDm`).
- **`persistence_verifier.py`**: Read-only verification of forward evidence snapshots and audit trail integrity.

## Safety & Isolation Rules

1. Monitoring scripts operate strictly as external observers; they cannot trigger broker trade executions.
2. Scripts must never embed or require broker credentials or machine-specific absolute file paths.
3. Supervision logic is decoupled from trading decisions.
