# NeuroPip Configuration Governance

This directory contains sanitized configuration templates for the **NeuroPip** system developed by **NextGen Technologies**.

## Safe Templates

- [`startup.ini.example`](./startup.ini.example): Template for MetaTrader 5 terminal initialization and Expert Advisor auto-attachment.
- [`runtime.example.json`](./runtime.example.json): Schema and default configuration parameters for system risk bounds, universe definition, and telemetry.

## Credential & Security Policy

1. **Zero Secrets in Repository:** Under no circumstances should broker account numbers, investor passwords, trading passwords, server names with private ports, or API secrets be committed to this repository.
2. **Local Overrides:** Local runtime configurations (`startup.ini`, `credentials.ini`, `.env`) are explicitly ignored by `.gitignore`.
3. **Machine Independence:** Configuration templates must use relative identifiers or environment variables rather than machine-specific absolute file paths or terminal installation hash directories.
4. **Execution Safety:** All default templates specify `can_trade = false` and `monitor_only = true` with execution guard locks active.
