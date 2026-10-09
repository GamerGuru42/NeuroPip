//+------------------------------------------------------------------+
//| AdaptiveTrendStrategy.mqh                                        |
//| NeuroPip - Experimental Strategy Candidate 1                     |
//| Identifier: NEUROPIP_ADAPTIVE_TREND                              |
//| Cohort: COHORT_EXP_01 (Track B)                                  |
//| Adaptive spread limits, dynamic volume floor, trend continuation |
//| MONITOR_ONLY - No real money execution                           |
//+------------------------------------------------------------------+
#ifndef NEUROPIP_ADAPTIVE_TREND_STRATEGY_MQH
#define NEUROPIP_ADAPTIVE_TREND_STRATEGY_MQH

#include "StrategyTypes.mqh"
#include "StrategyValidator.mqh"
#include "../Diagnostics/Logger.mqh"

class CAdaptiveTrendStrategy
{
private:
   CLogger*            m_logger;
   SStrategyParameters m_params;
   CStrategyValidator  m_validator;

   // Helper: get symbol-specific max spread
   int GetSymbolMaxSpread(const string symbol) const
   {
      if(StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "USDJPY") >= 0)
         return 35;   // 3.5 pips for FX
      if(StringFind(symbol, "XAUUSD") >= 0)
         return 350;  // $0.35 for Gold
      if(StringFind(symbol, "BTCUSD") >= 0)
         return 1000; // $10.00 for BTC
      if(StringFind(symbol, "ETHUSD") >= 0)
         return 150;  // $1.50 for ETH
      return 100;
   }

public:
   CAdaptiveTrendStrategy(CLogger* logger)
      : m_logger(logger),
        m_validator(logger)
   {
      m_params.Reset();
      m_params.strategy_id      = "NEUROPIP_ADAPTIVE_TREND";
      m_params.strategy_version = "1.0.0-exp";
      m_params.min_confidence   = 0.70;
      m_params.min_confluence   = 0.65;
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
      out_decision.direction         = candidate.direction;
      out_decision.strategy_id       = m_params.strategy_id;
      out_decision.strategy_version  = m_params.strategy_version;
      out_decision.primary_regime    = regime.primary_regime;
      out_decision.market_bias       = candidate.bias;
      out_decision.created_time      = TimeCurrent();
      out_decision.bar_time          = mtf.tf_m15.bar_time;
      out_decision.expiry_time       = out_decision.created_time + m_params.signal_expiry_sec;
      out_decision.confidence        = candidate.confidence;

      if(!candidate.is_candidate || candidate.direction == SIGNAL_DIR_NONE || candidate.direction == SIGNAL_DIR_NEUTRAL)
      {
         out_decision.status = STRATEGY_WAIT;
         out_decision.rejection_reason = STRAT_REJECT_NONE;
         out_decision.rejection_detail = "Waiting for adaptive trend setup.";
         return false;
      }

      // Check adaptive spread
      int sym_max_spread = GetSymbolMaxSpread(mtf.symbol);
      if(mtf.tf_m15.spread.spread_points > sym_max_spread)
      {
         out_decision.status = STRATEGY_REJECTED;
         out_decision.rejection_reason = STRAT_REJECT_EXCESSIVE_SPREAD;
         out_decision.rejection_detail = StringFormat("Spread %d pts exceeds adaptive limit %d pts",
            mtf.tf_m15.spread.spread_points, sym_max_spread);
         return false;
      }

      // Trend slope and momentum check
      bool is_buy = (candidate.direction == SIGNAL_DIR_BUY);
      double rsi = mtf.tf_m15.momentum.rsi;
      bool mom_ok = is_buy ? (rsi >= 45.0 && rsi <= 70.0) : (rsi >= 30.0 && rsi <= 55.0);

      if(!mom_ok)
      {
         out_decision.status = STRATEGY_REJECTED;
         out_decision.rejection_reason = STRAT_REJECT_MOMENTUM_INVALID;
         out_decision.rejection_detail = StringFormat("Adaptive RSI (%.1f) outside window", rsi);
         return false;
      }

      out_decision.status       = STRATEGY_APPROVED;
      out_decision.is_candidate = true;
      out_decision.is_approved  = true;
      out_decision.AddEvidence("ADAPTIVE_TREND: Passed adaptive spread and momentum filters");
      return true;
   }
};

#endif
