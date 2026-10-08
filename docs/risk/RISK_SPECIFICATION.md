# NeuroPip - Risk Specification

## 1. Core Risk Controls
The Risk Engine operates locally and unconditionally evaluates every trade candidate and open portfolio state.

- **Risk Per Trade**: Maximum % of equity or fixed cash amount allowed per signal.
- **Maximum Daily Loss**: Hard limit on realized and floating daily loss. Reaching this halts trading for the day.
- **Maximum Weekly Loss**: Hard limit spanning the trading week.
- **Maximum Account Drawdown**: Hard limit based on high-water mark equity.
- **Maximum Portfolio Exposure**: Maximum gross/net exposure across all open positions.
- **Correlation Exposure**: Prevents opening trades in highly correlated assets (e.g., Long EURUSD + Long GBPUSD) if it breaches total risk limits.
- **Strategy Exposure**: Limits the risk allocated to a single active strategy.
- **Consecutive-Loss Protection**: Reduces risk or pauses trading after a specified streak of losses.
- **Margin Safety**: Ensures sufficient free margin buffer exists before and after a trade.
- **Spread & Volatility Protection**: Rejects entries during spread blowouts or chaotic volatility spikes.
- **Emergency Stop & Safe Mode**: Circuit breakers triggered by extreme market moves or cloud disconnections.

## 2. Position Sizing
Volume is mathematically derived:
1. Determine absolute cash risk allowed (Equity * Risk %).
2. Calculate SL distance in points.
3. Fetch exact symbol tick size and tick value.
4. Compute raw volume.
5. Normalize volume against broker rules (minimum volume, maximum volume, volume step).
6. Verify margin requirements against available free margin.

## 3. Forbidden Practices (Strictly Enforced)
- **Martingale**: Increasing size after a loss to recover equity is forbidden.
- **Unlimited Averaging Down**: No unrestricted grid or cost-averaging without strict predefined risk caps.
- **Revenge Trading**: No bypassing timeouts or daily loss limits.
- **Widening Stop Losses**: A stop loss can only be trailed to reduce risk; it must never be widened to delay realizing a loss.
- **Bypassing Hard Stops**: Disabling broker-side stops is strictly prohibited.
