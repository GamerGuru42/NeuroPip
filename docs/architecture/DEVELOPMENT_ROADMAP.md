# NeuroPip - Development Roadmap

## Phase Definitions
- **Phase 0**: Architecture and specification (Current Phase).
- **Phase 1**: MT5 foundation and market-data engine.
- **Phase 2**: Execution engine.
- **Phase 3**: Risk engine.
- **Phase 4**: Market intelligence and regime engine.
- **Phase 5**: Forecast engine.
- **Phase 6**: Strategy engine.
- **Phase 7**: Signal-quality engine.
- **Phase 8**: Backtesting/research.
- **Phase 9**: ATG Cloud.
- **Phase 10**: Dashboard.
- **Phase 11**: Exness demo deployment.
- **Phase 12**: Controlled live deployment.
- **Phase 13**: Controlled optimization.

## Development Discipline
For every phase, the following loop must be strictly followed:
1. Explain architecture.
2. Define interfaces.
3. Implement.
4. Compile.
5. Run tests.
6. Inspect errors & Fix errors.
7. Re-run tests.
8. Document the result.
9. Verify exit criteria.

**Rule**: Never silently skip failed tests. Never replace missing implementation with placeholder code while claiming completion.
