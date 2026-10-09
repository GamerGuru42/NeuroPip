//+------------------------------------------------------------------+
//| MomentumBreakoutStrategy.mqh                                     |
//| NeuroPip - Experimental Strategy Candidate 3                     |
//| Identifier: NEUROPIP_MOMENTUM_BREAKOUT                           |
//| Cohort: COHORT_EXP_01 (Track B)                                  |
//| Donchian 20 Breakout with ATR expansion & directional RSI on H1  |
//| MONITOR_ONLY - No real money execution                           |
//+------------------------------------------------------------------+
#ifndef NEUROPIP_MOMENTUM_BREAKOUT_STRATEGY_MQH
#define NEUROPIP_MOMENTUM_BREAKOUT_STRATEGY_MQH

#include "StrategyTypes.mqh"
#include "StrategyValidator.mqh"
#include "SpreadPolicy.mqh"
#include "../Diagnostics/Logger.mqh"

class CMomentumBreakoutStrategy
{
private:
   CLogger*            m_logger;
   SStrategyParameters m_params;

public:
   CMomentumBreakoutStrategy(CLogger* logger)
      : m_logger(logger)
   {
      m_params.Reset();
      m_params.strategy_id      = "NEUROPIP_MOMENTUM_BREAKOUT";
      m_params.strategy_version = "1.0.0-exp";
      m_params.min_confidence   = 0.75;
   }

   SStrategyParameters GetParameters() const { return m_params; }
   void SetParameters(const SStrategyParameters &p) { m_params = p; }

   bool Evaluate(const SMultiTimeframeFeatures &mtf,
                 const SRegimeClassification &regime,
                 const SATGSignalCandidate &candidate,
                 ulong decision_id,
                 SStrategyDecision &out_decision)
   {
      out_decision.Reset();
      out_decision.decision_id       = decision_id;
      out_decision.symbol            = mtf.symbol;
      out_decision.primary_timeframe = PERIOD_H1;
      out_decision.strategy_id       = m_params.strategy_id;
      out_decision.strategy_version  = m_params.strategy_version;
      out_decision.primary_regime    = regime.primary_regime;
      out_decision.created_time      = TimeCurrent();
      out_decision.bar_time          = mtf.tf_h1.bar_time;
      out_decision.expiry_time       = out_decision.created_time + m_params.signal_expiry_sec;

      // Ensure H1 features are ready
      if(!mtf.tf_h1.data_ready || mtf.tf_h1.volatility.atr <= 0.0)
      {
         out_decision.status = STRATEGY_WAIT;
         out_decision.rejection_detail = "Waiting for H1 data readiness";
         return false;
      }

      // 1. Centralized Spread Policy check (Gate 7)
      double point_size = SymbolInfoDouble(mtf.symbol, SYMBOL_POINT);
      if(point_size <= 0.0) point_size = 0.00001;
      string spread_rej = "";
      if(!CSpreadPolicy::ValidateSpread(mtf.symbol, mtf.tf_h1.spread.spread_points, point_size, mtf.tf_h1.volatility.atr, 0.0, spread_rej))
      {
         out_decision.status = STRATEGY_REJECTED;
         out_decision.rejection_reason = STRAT_REJECT_EXCESSIVE_SPREAD;
         out_decision.rejection_detail = spread_rej;
         return false;
      }

      // 2. Volatility expansion check on completed H1 candle (Range >= 1.25 * ATR)
      double h1_range_price = mtf.tf_h1.price.range_points * point_size;
      bool atr_exp = (h1_range_price >= 1.25 * mtf.tf_h1.volatility.atr) || (mtf.tf_h1.volatility.atr_ratio_to_avg >= 1.20);

      // 3. Trend & Donchian Breakout on completed H1 candle
      bool ema_bull = (mtf.tf_h1.trend.fast_ma > mtf.tf_h1.trend.slow_ma); // EMA 20 > EMA 50
      bool ema_bear = (mtf.tf_h1.trend.fast_ma < mtf.tf_h1.trend.slow_ma); // EMA 20 < EMA 50

      double close_p  = mtf.tf_h1.price.close;
      double swing_hi = mtf.tf_h1.structure.recent_swing_high;
      double swing_lo = mtf.tf_h1.structure.recent_swing_low;
      double rsi      = mtf.tf_h1.momentum.rsi;

      // Buy breakout: EMA bull + close >= swing_hi + ATR expansion + RSI > 58
      if(ema_bull && close_p >= swing_hi && atr_exp && rsi > 58.0)
      {
         out_decision.direction    = SIGNAL_DIR_BUY;
         out_decision.status       = STRATEGY_APPROVED;
         out_decision.is_candidate = true;
         out_decision.is_approved  = true;
         out_decision.confidence   = 0.85;
         out_decision.quality_score = 0.88;
         out_decision.AddEvidence(StringFormat("MOMENTUM_BREAKOUT BUY: H1 Close (%.5f) >= Donchian High (%.5f), EMA20>50, Range Ratio %.2f, RSI %.1f",
            close_p, swing_hi, h1_range_price / mtf.tf_h1.volatility.atr, rsi));
         return true;
      }
      // Sell breakout: EMA bear + close <= swing_lo + ATR expansion + RSI < 42
      else if(ema_bear && close_p <= swing_lo && atr_exp && rsi < 42.0)
      {
         out_decision.direction    = SIGNAL_DIR_SELL;
         out_decision.status       = STRATEGY_APPROVED;
         out_decision.is_candidate = true;
         out_decision.is_approved  = true;
         out_decision.confidence   = 0.85;
         out_decision.quality_score = 0.88;
         out_decision.AddEvidence(StringFormat("MOMENTUM_BREAKOUT SELL: H1 Close (%.5f) <= Donchian Low (%.5f), EMA20<50, Range Ratio %.2f, RSI %.1f",
            close_p, swing_lo, h1_range_price / mtf.tf_h1.volatility.atr, rsi));
         return true;
      }

      out_decision.status = STRATEGY_WAIT;
      if(!atr_exp)
         out_decision.rejection_detail = StringFormat("Waiting for H1 volatility expansion (Bar Range %.1f pts < 1.25*ATR %.1f pts)", mtf.tf_h1.price.range_points, 1.25 * mtf.tf_h1.volatility.atr_points);
      else if(ema_bull && close_p < swing_hi)
         out_decision.rejection_detail = StringFormat("Bullish trend, waiting for H1 breakout above %.5f (Current: %.5f)", swing_hi, close_p);
      else if(ema_bear && close_p > swing_lo)
         out_decision.rejection_detail = StringFormat("Bearish trend, waiting for H1 breakout below %.5f (Current: %.5f)", swing_lo, close_p);
      else
         out_decision.rejection_detail = StringFormat("Waiting for RSI momentum trigger (Current RSI: %.1f)", rsi);

      return false;
   }
};

#endif
