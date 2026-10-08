//+------------------------------------------------------------------+
//| MarketIntelligenceEngine.mqh                                     |
//| ATG Trading Engine - Phase 3                                     |
//| Central Market Intelligence Coordinator                          |
//| Orchestrates Features -> Regime -> Signal Candidate              |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_MARKET_INTELLIGENCE_ENGINE_MQH
#define ATG_MARKET_INTELLIGENCE_ENGINE_MQH

#include "MarketFeatureEngine.mqh"
#include "MarketRegimeEngine.mqh"
#include "SignalEngine.mqh"
#include "../MarketData/SymbolUniverseManager.mqh"
#include "../MarketData/MarketStateCache.mqh"
#include "../MarketData/BarDataManager.mqh"
#include "../Diagnostics/Logger.mqh"

struct SSymbolIntelligenceState
{
   string                   symbol;
   SMultiTimeframeFeatures  features;
   SRegimeClassification   regime;
   SATGSignalCandidate      signal;
   datetime                 last_analysis_time;
   ENUM_ATG_MARKET_REGIME   last_logged_regime;
   ENUM_ATG_SIGNAL_QUALITY  last_logged_quality;
};

class CMarketIntelligenceEngine
{
private:
   CLogger*                m_logger;
   CMarketFeatureEngine*   m_features;
   CMarketRegimeEngine*    m_regimes;
   CSignalEngine*          m_signals;
   CSymbolUniverseManager* m_universe;
   CMarketStateCache*      m_cache;
   CBarDataManager*        m_bar_manager;

   SSymbolIntelligenceState m_states[];

   //+----------------------------------------------------------------+
   //| Find symbol state slot                                         |
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
   //| Ensure symbol slot exists                                      |
   //+----------------------------------------------------------------+
   int EnsureSlot(const string symbol)
   {
      int idx = FindSlot(symbol);
      if(idx >= 0)
         return idx;

      int size = ArraySize(m_states);
      ArrayResize(m_states, size + 1);
      m_states[size].symbol               = symbol;
      m_states[size].last_analysis_time   = 0;
      m_states[size].last_logged_regime   = REGIME_INSUFFICIENT_DATA;
      m_states[size].last_logged_quality  = SIGNAL_QUALITY_NONE;
      m_states[size].features.Reset();
      m_states[size].regime.Reset();
      m_states[size].signal.Reset();

      return size;
   }

public:
   CMarketIntelligenceEngine(CLogger* logger,
                             CMarketFeatureEngine* features,
                             CMarketRegimeEngine* regimes,
                             CSignalEngine* signals,
                             CSymbolUniverseManager* universe,
                             CMarketStateCache* cache,
                             CBarDataManager* bar_manager)
      : m_logger(logger),
        m_features(features),
        m_regimes(regimes),
        m_signals(signals),
        m_universe(universe),
        m_cache(cache),
        m_bar_manager(bar_manager)
   {
   }

   //+----------------------------------------------------------------+
   //| Initialize storage for symbol universe                         |
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
         m_logger.Log(LOG_LEVEL_INFO, "Intelligence", "INIT_SUCCESS",
            StringFormat("Market Intelligence initialized for %d symbols.", ArraySize(m_states)));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Analyze a single symbol through Features -> Regime -> Signal   |
   //+----------------------------------------------------------------+
   bool AnalyzeSymbol(const string symbol, bool force_log = false)
   {
      if(symbol == "")
         return false;

      int slot = EnsureSlot(symbol);
      datetime now = TimeCurrent();

      // Step 1: Extract Multi-Timeframe Features
      bool feat_ok = m_features.ExtractMultiTimeframeFeatures(symbol, m_states[slot].features);

      if(!feat_ok)
      {
         if(force_log && m_logger != NULL)
         {
            m_logger.Log(LOG_LEVEL_NOTICE, "Intelligence", "INSUFFICIENT_DATA",
               StringFormat("%s: Insufficient historical bars for multi-timeframe analysis.", symbol));
         }
         m_states[slot].regime.Reset();
         m_states[slot].signal.Reset();
         m_states[slot].last_analysis_time = now;
         return false;
      }

      // Step 2: Classify Market Regime
      bool regime_ok = m_regimes.Classify(m_states[slot].features, m_states[slot].regime);

      // Step 3: Evaluate Candidate Signal
      bool has_candidate = m_signals.Evaluate(m_states[slot].features,
                                              m_states[slot].regime,
                                              m_states[slot].signal);

      m_states[slot].last_analysis_time = now;

      // Step 4: Structured Diagnostics & Logging
      bool regime_changed = (m_states[slot].regime.primary_regime != m_states[slot].last_logged_regime);
      bool quality_changed = (m_states[slot].signal.quality != m_states[slot].last_logged_quality);

      if(force_log || regime_changed || quality_changed || has_candidate)
      {
         m_states[slot].last_logged_regime  = m_states[slot].regime.primary_regime;
         m_states[slot].last_logged_quality = m_states[slot].signal.quality;

         if(m_logger != NULL)
         {
            // Log features
            m_logger.Log(LOG_LEVEL_INFO, "Intelligence", "MARKET_FEATURES",
               StringFormat("%s | H1 Trend: %s (EMA20=%.5f EMA50=%.5f) | M15 ATR: %.1f pts (Vol: %s) | RSI: %.1f | Spread: %d pts",
                  symbol,
                  EnumToString(m_states[slot].features.tf_h1.trend.trend_direction),
                  m_states[slot].features.tf_h1.trend.fast_ma,
                  m_states[slot].features.tf_h1.trend.slow_ma,
                  m_states[slot].features.tf_m15.volatility.atr_points,
                  EnumToString(m_states[slot].features.tf_m15.volatility.vol_state),
                  m_states[slot].features.tf_m15.momentum.rsi,
                  m_states[slot].features.tf_m15.spread.spread_points));

            // Log regime
            m_logger.Log(LOG_LEVEL_INFO, "Intelligence", "REGIME_CLASSIFIED",
               StringFormat("%s | Regime: %s | Trend: %s | Vol: %s | Struct: %s | Conf: %.2f",
                  symbol,
                  m_states[slot].regime.regime_name,
                  RegimeTrendToString(m_states[slot].regime.trend_dimension),
                  RegimeVolToString(m_states[slot].regime.vol_dimension),
                  RegimeStructToString(m_states[slot].regime.struct_dimension),
                  m_states[slot].regime.confidence));

            // Log signal candidate or wait state
            if(has_candidate)
            {
               m_logger.Log(LOG_LEVEL_INFO, "Intelligence", "SIGNAL_CANDIDATE",
                  StringFormat("CANDIDATE DETECTED | %s %s | Quality: %s | Conf: %.2f | Status: CANDIDATE_ONLY (NO EXECUTION)",
                     symbol,
                     m_states[slot].signal.DirectionToString(),
                     m_states[slot].signal.QualityToString(),
                     m_states[slot].signal.confidence));
            }
            else
            {
               m_logger.Log(LOG_LEVEL_INFO, "Intelligence", "NO_SIGNAL",
                  StringFormat("%s | Bias: %s | Quality: %s | Market observed - waiting for confluence setup.",
                     symbol,
                     m_states[slot].signal.BiasToString(),
                     m_states[slot].signal.QualityToString()));
            }
         }
      }

      return has_candidate;
   }

   //+----------------------------------------------------------------+
   //| Analyze all symbols in universe                                |
   //+----------------------------------------------------------------+
   int AnalyzeAll(bool force_log = false)
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

         if(AnalyzeSymbol(symbol, force_log))
            candidate_count++;
      }

      return candidate_count;
   }

   //+----------------------------------------------------------------+
   //| Process periodic closed-bar analysis                           |
   //+----------------------------------------------------------------+
   void ProcessOnBar()
   {
      // Analyze symbols that had new closed bars detected
      int count = m_universe.GetSymbolCount();
      for(int i = 0; i < count; i++)
      {
         if(!m_universe.IsAvailable(i))
            continue;

         string symbol = m_universe.GetBrokerSymbol(i);
         if(symbol == "")
            continue;

         // Check if a new closed bar was detected on M15 or H1
         bool new_m15 = m_bar_manager.IsNewBar(symbol, PERIOD_M15);
         bool new_h1  = m_bar_manager.IsNewBar(symbol, PERIOD_H1);

         if(new_m15 || new_h1)
         {
            AnalyzeSymbol(symbol, false);
         }
      }
   }

   //+----------------------------------------------------------------+
   //| Accessors for query and diagnostics                            |
   //+----------------------------------------------------------------+
   bool GetLatestSignal(const string symbol, SATGSignalCandidate &out_signal)
   {
      int slot = FindSlot(symbol);
      if(slot < 0) return false;
      out_signal = m_states[slot].signal;
      return out_signal.is_valid;
   }

   bool GetLatestRegime(const string symbol, SRegimeClassification &out_regime)
   {
      int slot = FindSlot(symbol);
      if(slot < 0) return false;
      out_regime = m_states[slot].regime;
      return out_regime.is_valid;
   }

   bool GetLatestFeatures(const string symbol, SMultiTimeframeFeatures &out_features)
   {
      int slot = FindSlot(symbol);
      if(slot < 0) return false;
      out_features = m_states[slot].features;
      return out_features.overall_data_ready;
   }
};

#endif
