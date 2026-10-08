# NeuroPip Automated Test Suites

**NextGen Technologies — Verification & Quality Assurance**

## Overview

This directory houses the comprehensive test suites for **NeuroPip**, spanning unit tests, regression suites, statistical validation runners, and simulated paper execution harnesses.

## Test Suite Architecture

- **`unit/`**: Component-level tests for market indicators, ATR sizer, risk budgeting, and regime classification algorithms.
- **`integration/`**: Cross-module verification covering signal candidate generation, trade planning, and `CExecutionGuard` hard-lock boundaries.
- **`mql5_scripts/`**: Automated MQL5 test runners (including Phase 1 through Phase 10 validation scripts) executed within MetaTrader 5 test environments.
- **`runners/`**: Automated execution wrappers for headless batch test invocation and report generation.

## Test Quality Gates

All pull requests and version increments require:
- 100% pass rate across all unit and integration test suites.
- Verified immutability of the frozen strategy fingerprint (`FP-B741A5209E579706`).
- Verified zero broker order transmission during simulation runs.
