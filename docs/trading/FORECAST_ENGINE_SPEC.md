# ATG Trading Engine - Forecast Engine Spec

## 1. Purpose
The Forecast Engine is responsible for generating a structured, objective assessment of the market. It does not generate trade signals; it provides the probabilistic context that the Strategy Engine consumes.

## 2. Evaluation Vectors
Where supported by data, the Forecast Engine evaluates:
- **Directional Bias**: Is the path of least resistance up, down, or neutral?
- **Trend Continuation / Reversal Risk**: Probability of the current structure holding vs. failing.
- **Momentum & Volatility**: Strength and speed of the current price action.
- **Expected Movement**: ATR-based or standard deviation-based movement expectations.
- **Market Structure**: Key structural nodes, swing highs/lows.
- **Liquidity**: Assessing order book depth (if available) or tick volume quality.
- **Adverse/Favorable Movement Potential**: Reward-to-risk estimations based on nearby structure.
- **Forecast Confidence**: An internal metric (0-100) indicating the clarity of the current data.

## 3. Principles
- **No Absolute Certainty**: The system does not claim to predict the future. All assessments are probabilistic.
- **Forecast != Signal**: A highly confident Bullish forecast may result in NO TRADE if the spread is too high, risk limits are reached, or no specific strategy setup aligns with the entry criteria.
