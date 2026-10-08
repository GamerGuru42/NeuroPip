//+------------------------------------------------------------------+
//| StrategyDecisionEngine.mqh                                       |
//| NeuroPip - Phase 4                                     |
//| Central Strategy Decision Coordinator                            |
//| Multi-Symbol State Management, Duplicate Control & Diagnostics   |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_STRATEGY_DECISION_ENGINE_MQH
#define ATG_STRATEGY_DECISION_ENGINE_MQH

#include "StrategyTypes.mqh"
#include "TrendContinuationStrategy.mqh"
#include "../Intelligence/MarketIntelligenceEngine.mqh"
#include "../MarketData/SymbolUniverseManager.mqh"
#include "../Diagnostics/Logger.mqh"

struct SSymbolStrategyState
{
   string                        symbol;
   SStrategyDecision             latest_decision;
   datetime                      last_evaluated_bar_time;
   datetime                      last_evaluation_time;
   ENUM_STRATEGY_DECISION_STATUS last_logged_status;
};

class CStrategyDecisionEngine
{
private:
   CLogger*                    m_logger;
   CMarketIntelligenceEngine*  m_intelligence;
   CSymbolUniverseManager*     m_universe;

   CTrendContinuationStrategy  m_trend_strategy;

   SSymbolStrategyState        m_states[];
   ulong                       m_decision_counter;

   //+----------------------------------------------------------------+
   //| Find slot for symbol                                           |
   //+----------------------------------------------------------------+
   int FindSlot(const string symbol)
   {
      for(int i = 0; i < ArraySize(m_states); i++)
      {
         if(m_states[i].symbol == symbol)
            return i;
      }
      return -1;
   }

   //+----------------------------------------------------------------+
   //| Ensure slot exists for symbol                                  |
   //+----------------------------------------------------------------+
   int EnsureSlot(const string symbol)
   {
      int idx = FindSlot(symbol);
      if(idx >= 0)
         return idx;

      int size = ArraySize(m_states);
      ArrayResize(m_states, size + 1);
      m_states[size].symbol                  = symbol;
      m_states[size].last_evaluated_bar_time = 0;
      m_states[size].last_evaluation_time    = 0;
      m_states[size].last_logged_status      = STRATEGY_WAIT;
      m_states[size].latest_decision.Reset();

      return size;
   }

public:
   CStrategyDecisionEngine(CLogger* logger,
                           CMarketIntelligenceEngine* intelligence,
                           CSymbolUniverseManager* universe)
      : m_logger(logger),
        m_intelligence(intelligence),
        m_universe(universe),
        m_trend_strategy(logger),
        m_decision_counter(4000000)
   {
   }

   // Strategy accessors
   CTrendContinuationStrategy* GetTrendStrategy() { return &m_trend_strategy; }

   //+----------------------------------------------------------------+
   //| Initialize engine for universe                                 |
   //+----------------------------------------------------------------+
   bool Initialize()
   {
      int count = m_universe.GetSymbolCount();
      ArrayResize(m_states, 0);

      for(int i = 0; i < count; i++)
      {
         string sym = m_universe.GetBrokerSymbol(i);
         if(sym != "")
            EnsureSlot(sym);
      }

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "StrategyEngine", "INIT_SUCCESS",
            StringFormat("Strategy Decision Engine initialized for %d symbols.", ArraySize(m_states)));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Evaluate strategy candidate for a single symbol                |
   //+----------------------------------------------------------------+
   bool EvaluateSymbol(const string symbol, bool force_eval = false)
   {
      if(symbol == "")
         return false;

      int slot = EnsureSlot(symbol);

      // 1. Retrieve latest Phase 3 Intelligence State
      SMultiTimeframeFeatures mtf;
      SRegimeClassification  regime;
      SATGSignalCandidate     signal;

      bool feat_ok = m_intelligence.GetLatestFeatures(symbol, mtf);
      bool reg_ok  = m_intelligence.GetLatestRegime(symbol, regime);
      bool sig_ok  = m_intelligence.GetLatestSignal(symbol, signal);

      if(!feat_ok || !reg_ok)
      {
         m_states[slot].latest_decision.Reset();
         m_states[slot].latest_decision.symbol = symbol;
         m_states[slot].latest_decision.status = STRATEGY_INSUFFICIENT_DATA;
         m_states[slot].latest_decision.rejection_reason = STRAT_REJECT_INSUFFICIENT_DATA;
         m_states[slot].latest_decision.rejection_detail = "Phase 3 Market Intelligence incomplete or unavailable.";

         if(m_states[slot].last_logged_status != STRATEGY_INSUFFICIENT_DATA && m_logger != NULL)
         {
            m_states[slot].last_logged_status = STRATEGY_INSUFFICIENT_DATA;
            m_logger.Log(LOG_LEVEL_NOTICE, "StrategyEngine", "STRATEGY_INSUFFICIENT_DATA",
               StringFormat("%s: Insufficient Phase 3 intelligence data for strategy evaluation.", symbol));
         }
         return false;
      }

      // 2. Duplicate Signal Suppression (check M15 bar timestamp)
      datetime current_bar_time = mtf.tf_m15.bar_time;
      if(!force_eval && current_bar_time > 0 && current_bar_time == m_states[slot].last_evaluated_bar_time)
      {
         // Same bar already evaluated: suppress duplicate processing
         return (m_states[slot].latest_decision.status == STRATEGY_APPROVED);
      }

      // Increment decision ID
      m_decision_counter++;
      ulong dec_id = m_decision_counter;

      // 3. Evaluate Strategy
      SStrategyDecision decision;
      bool is_approved = m_trend_strategy.Evaluate(mtf, regime, signal, dec_id, decision);

      m_states[slot].latest_decision         = decision;
      m_states[slot].last_evaluated_bar_time = current_bar_time;
      m_states[slot].last_evaluation_time    = TimeCurrent();

      // 4. Structured Diagnostics & Logging
      bool status_changed = (decision.status != m_states[slot].last_logged_status);
      if(force_eval || status_changed || is_approved)
      {
         m_states[slot].last_logged_status = decision.status;

         if(m_logger != NULL)
         {
            if(decision.status == STRATEGY_APPROVED)
            {
               m_logger.Log(LOG_LEVEL_INFO, "StrategyEngine", "STRATEGY_CANDIDATE",
                  StringFormat("STRATEGY CANDIDATE QUALIFIED | %s %s [%s] | Conf: %.2f | Quality: %.2f | Regime: %s | (CANDIDATE ONLY - NO EXECUTION)",
                     symbol,
                     decision.DirectionToString(),
                     decision.strategy_id,
                     decision.confidence,
                     decision.quality_score,
                     EnumToString(decision.primary_regime)));

               // Log full explainability block
               Print(decision.formatted_explanation);
            }
            else if(decision.status == STRATEGY_REJECTED)
            {
               m_logger.Log(LOG_LEVEL_INFO, "StrategyEngine", "STRATEGY_REJECTED",
                  StringFormat("%s: %s rejected by strategy %s. Reason: %s (%s)",
                     symbol,
                     decision.DirectionToString(),
                     decision.strategy_id,
                     decision.RejectionToString(),
                     decision.rejection_detail));
            }
            else if(decision.status == STRATEGY_WAIT)
            {
               m_logger.Log(LOG_LEVEL_INFO, "StrategyEngine", "STRATEGY_WAIT",
                  StringFormat("%s: Strategy %s in WAIT state (no candidate setup).",
                     symbol, decision.strategy_id));
            }
         }
      }

      return is_approved;
   }

   //+----------------------------------------------------------------+
   //| Evaluate all symbols in universe                               |
   //+----------------------------------------------------------------+
   int EvaluateAll(bool force_eval = false)
   {
      int candidate_count = 0;
      int count = m_universe.GetSymbolCount();

      for(int i = 0; i < count; i++)
      {
         if(!m_universe.IsAvailable(i))
            continue;

         string symbol = m_universe.GetBrokerSymbol(i);
         if(symbol == "")
            continue;

         if(EvaluateSymbol(symbol, force_eval))
            candidate_count++;
      }

      return candidate_count;
   }

   //+----------------------------------------------------------------+
   //| Process on closed-bar events                                   |
   //+----------------------------------------------------------------+
   void ProcessOnBar()
   {
      EvaluateAll(false);
   }

   //+----------------------------------------------------------------+
   //| Accessor for latest decision                                   |
   //+----------------------------------------------------------------+
   bool GetLatestDecision(const string symbol, SStrategyDecision &out_decision)
   {
      int slot = FindSlot(symbol);
      if(slot < 0) return false;
      out_decision = m_states[slot].latest_decision;
      return (out_decision.decision_id > 0);
   }
};

#endif
