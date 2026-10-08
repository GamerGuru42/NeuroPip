# NeuroPip Telemetry & Event Contracts

**NextGen Technologies — Observability & Telemetry Specifications**

## Overview

This directory defines the event contracts, data schemas, and serialization formats for **NeuroPip** observability. Telemetry provides transparency into system health and forward-paper evidence without compromising execution security.

## Core Telemetry Events

| Event Type | Description | Frequency / Trigger |
|---|---|---|
| `HEARTBEAT` | Symbol feed status, spread (pts), and engine timestamp | Periodic (every 60s per active symbol) |
| `REGIME_TRANSITION` | Detected shifts in market volatility and trend regime | On timeframe candle close |
| `CANDIDATE_SIGNAL` | Strategy signal evaluations and rejection reasons | On bar evaluation |
| `TRADE_SIMULATED` | Paper trade opens, trailing adjustments, and exits | On paper fill event |
| `MILESTONE_EVAL` | Statistical evidence progress ($N$ count, win rate, expectancy) | Hourly / On trade close |
| `SAFETY_ALERT` | Execution guard intercepts and threshold warnings | Event-driven |

## Non-Custodial Design

The telemetry subsystem is strictly egress-only and read-only. External telemetry collectors cannot send control commands or alter risk parameters on the running MetaTrader 5 terminal.
