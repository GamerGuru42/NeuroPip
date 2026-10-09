//+------------------------------------------------------------------+
//| PullbackContinuationStrategy.mqh                                 |
//| NeuroPip - Experimental Strategy Candidate 2                     |
//| Identifier: NEUROPIP_PULLBACK_CONTINUATION                       |
//| Cohort: COHORT_EXP_01 (Track B)                                  |
//| Value zone retracement into EMA20/50 with macro trend align      |
//| MONITOR_ONLY - No real money execution                           |
//+------------------------------------------------------------------+
#ifndef NEUROPIP_PULLBACK_CONTINUATION_STRATEGY_MQH
#define NEUROPIP_PULLBACK_CONTINUATION_STRATEGY_MQH

#include "StrategyTypes.mqh"
#include "StrategyValidator.mqh"
#include "../Diagnostics/Logger.mqh"

class CPullbackContinuationStrategy
{
private:
   CLogger*            m_logger;
   SStrategyParameters m_params;

   int GetSymbolMaxSpread(const string symbol) const
   {
      if(StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "USDJPY") >= 0)
         return 35;
      if(StringFind(symbol, "XAUUSD") >= 0)
         return 350;
      if(StringFind(symbol, "BTCUSD") >= 0)
         return 1000;
      if(StringFind(symbol, "ETHUSD") >= 0)
         return 150;
      return 100;
   }

public:
   CPullbackContinuationStrategy(CLogger* logger)
      : m_logger(logger)
   {
      m_params.Reset();
      m_params.strategy_id      = "NEUROPIP_PULLBACK_CONTINUATION";
      m_params.strategy_version = "1.0.0-exp";
      m_params.min_confidence   = 0.70;
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
      out_decision.primary_timeframe = PERIOD_M15;
      out_decision.strategy_id       = m_params.strategy_id;
      out_decision.strategy_version  = m_params.strategy_version;
      out_decision.primary_regime    = regime.primary_regime;
      out_decision.created_time      = TimeCurrent();
      out_decision.bar_time          = mtf.tf_m15.bar_time;
      out_decision.expiry_time       = out_decision.created_time + m_params.signal_expiry_sec;

      // Spread gate
      int sym_max_spread = GetSymbolMaxSpread(mtf.symbol);
      if(mtf.tf_m15.spread.spread_points > sym_max_spread)
      {
         out_decision.status = STRATEGY_REJECTED;
         out_decision.rejection_reason = STRAT_REJECT_EXCESSIVE_SPREAD;
         out_decision.rejection_detail = StringFormat("Spread %d pts exceeds limit %d pts",
            mtf.tf_m15.spread.spread_points, sym_max_spread);
         return false;
      }

      // Macro Trend: H1 EMA20 vs EMA50
      bool h1_bull = (mtf.tf_h1.trend.trend_direction == TREND_BULLISH);
      bool h1_bear = (mtf.tf_h1.trend.trend_direction == TREND_BEARISH);

      if(!h1_bull && !h1_bear)
      {
         out_decision.status = STRATEGY_WAIT;
         out_decision.rejection_detail = "H1 macro trend undefined";
         return false;
      }

      // M15 Pullback zone & RSI dip recovery
      double rsi = mtf.tf_m15.momentum.rsi;
      if(h1_bull)
      {
         // Bullish pullback: RSI was dip, recovering around 45-55
         if(rsi >= 42.0 && rsi <= 56.0)
         {
            out_decision.direction    = SIGNAL_DIR_BUY;
            out_decision.status       = STRATEGY_APPROVED;
            out_decision.is_candidate = true;
            out_decision.is_approved  = true;
            out_decision.confidence   = 0.78;
            out_decision.AddEvidence("PULLBACK_CONTINUATION: H1 Bullish + M15 Retracement value zone");
            return true;
         }
      }
      else if(h1_bear)
      {
         // Bearish pullback: RSI was bounce, recovering around 44-58
         if(rsi >= 44.0 && rsi <= 58.0)
         {
            out_decision.direction    = SIGNAL_DIR_SELL;
            out_decision.status       = STRATEGY_APPROVED;
            out_decision.is_candidate = true;
            out_decision.is_approved  = true;
            out_decision.confidence   = 0.78;
            out_decision.AddEvidence("PULLBACK_CONTINUATION: H1 Bearish + M15 Retracement value zone");
            return true;
         }
      }

      out_decision.status = STRATEGY_WAIT;
      out_decision.rejection_detail = "Waiting for clean pullback entry";
      return false;
   }
};

#endif
