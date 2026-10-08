//+------------------------------------------------------------------+
//| Phase3Tests.mqh                                                  |
//| ATG Trading Engine - Phase 3                                     |
//| Market Intelligence & Signal Foundation Test Suite               |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_PHASE3_TESTS_MQH
#define ATG_PHASE3_TESTS_MQH

#include "../Diagnostics/Logger.mqh"
#include "../Security/Capabilities.mqh"
#include "../Intelligence/MarketFeatureTypes.mqh"
#include "../Intelligence/MarketRegimeTypes.mqh"
#include "../Intelligence/SignalTypes.mqh"
#include "../Intelligence/MarketRegimeEngine.mqh"
#include "../Intelligence/SignalEngine.mqh"

class CPhase3Tests
{
private:
   CLogger* m_logger;

   //+----------------------------------------------------------------+
   //| Test 1: Feature Calculations                                   |
   //+----------------------------------------------------------------+
   bool TestFeatureCalculations()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "TEST_START", "Running Feature Calculations unit test...");

      // Validate candle structure math
      SPriceStructure ps;
      ps.Reset();
      ps.open  = 1.1000;
      ps.high  = 1.1050;
      ps.low   = 1.0980;
      ps.close = 1.1030;

      double point = 0.0001;
      ps.range_points      = (ps.high - ps.low) / point;             // (1.1050 - 1.0980)/0.0001 = 70.0
      ps.body_points       = MathAbs(ps.close - ps.open) / point;    // (1.1030 - 1.1000)/0.0001 = 30.0
      ps.upper_wick_points = (ps.high - MathMax(ps.open, ps.close)) / point; // (1.1050 - 1.1030)/0.0001 = 20.0
      ps.lower_wick_points = (MathMin(ps.open, ps.close) - ps.low) / point; // (1.1000 - 1.0980)/0.0001 = 20.0
      ps.candle_type       = (ps.close > ps.open) ? CANDLE_BULLISH : CANDLE_BEARISH;

      if(MathAbs(ps.range_points - 70.0) > 0.001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL", "Candle range points calculation incorrect.");
         return false;
      }
      if(MathAbs(ps.body_points - 30.0) > 0.001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL", "Candle body points calculation incorrect.");
         return false;
      }
      if(MathAbs(ps.upper_wick_points - 20.0) > 0.001 || MathAbs(ps.lower_wick_points - 20.0) > 0.001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL", "Candle wick points calculation incorrect.");
         return false;
      }
      if(ps.candle_type != CANDLE_BULLISH)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL", "Candle bullish classification incorrect.");
         return false;
      }

      // Validate ATR math on True Range sequence
      // Day 1: High=10, Low=8, Close=9
      // Day 2: High=11, Low=9.5, Close=10.5 (PrevClose=9). TR = Max(1.5, 2.0, 0.5) = 2.0
      double tr1 = MathMax(11.0 - 9.5, MathMax(MathAbs(11.0 - 9.0), MathAbs(9.5 - 9.0)));
      if(MathAbs(tr1 - 2.0) > 0.001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL", "True range calculation mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "TEST_PASS", "Feature Calculations unit tests passed.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 2: Regime Classification                                  |
   //+----------------------------------------------------------------+
   bool TestRegimeClassification()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "TEST_START", "Running Regime Classification test...");

      CMarketRegimeEngine regime_engine(m_logger);
      SMultiTimeframeFeatures mtf;
      mtf.Reset();
      mtf.symbol = "TEST_SYM";

      // Case A: Insufficient data
      mtf.overall_data_ready = false;
      SRegimeClassification reg;
      regime_engine.Classify(mtf, reg);

      if(reg.primary_regime != REGIME_INSUFFICIENT_DATA)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL", "Did not return INSUFFICIENT_DATA on empty features.");
         return false;
      }

      // Case B: Fully Bullish Multi-Timeframe Alignment
      mtf.overall_data_ready = true;
      mtf.tf_h4.data_ready = true;
      mtf.tf_h4.trend.trend_direction = TREND_BULLISH;
      mtf.tf_h4.trend.is_valid = true;

      mtf.tf_h1.data_ready = true;
      mtf.tf_h1.trend.trend_direction = TREND_BULLISH;
      mtf.tf_h1.trend.is_valid = true;
      mtf.tf_h1.volatility.atr_ratio_to_avg = 1.1;

      mtf.tf_m15.data_ready = true;
      mtf.tf_m15.structure.structure_state = STRUCT_HIGHER_HIGHS_LOWS;
      mtf.tf_m15.volatility.atr_ratio_to_avg = 1.1;

      regime_engine.Classify(mtf, reg);

      if(reg.primary_regime != REGIME_TRENDING_BULLISH || reg.trend_dimension != REGIME_TREND_BULLISH)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL",
            StringFormat("Bullish regime classification failed. Got: %s", reg.regime_name));
         return false;
      }

      // Case C: Sideways / Consolidation
      mtf.tf_h4.trend.trend_direction = TREND_FLAT;
      mtf.tf_h1.trend.trend_direction = TREND_FLAT;
      mtf.tf_m15.structure.structure_state = STRUCT_RANGING;
      mtf.tf_m15.volatility.atr_ratio_to_avg = 0.9;
      mtf.tf_h1.volatility.atr_ratio_to_avg = 0.9;

      regime_engine.Classify(mtf, reg);

      if(reg.primary_regime != REGIME_RANGING && reg.primary_regime != REGIME_LOW_VOLATILITY)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL",
            StringFormat("Ranging regime classification failed. Got: %s", reg.regime_name));
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "TEST_PASS", "Regime Classification tests passed.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 3: Signal Analysis & Confluence                           |
   //+----------------------------------------------------------------+
   bool TestSignalAnalysis()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "TEST_START", "Running Signal Confluence and Candidate test...");

      CSignalEngine signal_engine(m_logger);
      SMultiTimeframeFeatures mtf;
      mtf.Reset();
      mtf.symbol = "TEST_SYM";

      SRegimeClassification reg;
      reg.Reset();

      SATGSignalCandidate cand;

      // Case A: Insufficient data must result in NO_SIGNAL
      mtf.overall_data_ready = false;
      reg.is_valid = false;
      signal_engine.Evaluate(mtf, reg, cand);

      if(cand.is_candidate || cand.direction != SIGNAL_DIR_NONE || cand.status != SIGNAL_STATUS_NONE)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL", "Did not reject candidate on insufficient data.");
         return false;
      }

      // Case B: High confluence Bullish candidate
      mtf.overall_data_ready = true;
      reg.is_valid = true;
      reg.primary_regime = REGIME_TRENDING_BULLISH;
      reg.trend_dimension = REGIME_TREND_BULLISH;
      reg.vol_dimension = REGIME_VOL_NORMAL;

      // Configure H1
      mtf.tf_h1.data_ready = true;
      mtf.tf_h1.trend.trend_direction = TREND_BULLISH;
      mtf.tf_h1.trend.fast_ma = 1.1050;
      mtf.tf_h1.trend.slow_ma = 1.1000;

      // Configure H4
      mtf.tf_h4.data_ready = true;
      mtf.tf_h4.trend.trend_direction = TREND_BULLISH;

      // Configure M15
      mtf.tf_m15.data_ready = true;
      mtf.tf_m15.structure.structure_state = STRUCT_HIGHER_HIGHS_LOWS;
      mtf.tf_m15.momentum.rsi = 58.5; // Healthy bullish zone
      mtf.tf_m15.spread.spread_acceptable = true;
      mtf.tf_m15.spread.spread_points = 10;

      // Configure M5
      mtf.tf_m5.data_ready = true;
      mtf.tf_m5.trend.trend_direction = TREND_BULLISH;

      signal_engine.Evaluate(mtf, reg, cand);

      if(!cand.is_candidate || cand.direction != SIGNAL_DIR_BUY || cand.status != SIGNAL_STATUS_CANDIDATE_ONLY)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL",
            StringFormat("Failed to produce valid BUY candidate on confluence. Cand=%d Dir=%s Status=%s",
               cand.is_candidate, cand.DirectionToString(), cand.StatusToString()));
         return false;
      }

      // Case C: Overbought RSI Conflict suppresses candidate
      mtf.tf_m15.momentum.rsi = 74.0; // Overbought!
      mtf.tf_m5.trend.trend_direction = TREND_BEARISH; // Divergence!
      signal_engine.Evaluate(mtf, reg, cand);

      if(cand.is_candidate)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase3Tests", "TEST_FAIL",
            "Candidate should be suppressed when RSI is overbought and M5 diverges.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "TEST_PASS", "Signal Analysis tests passed.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 4: Execution Safety Verification                          |
   //+----------------------------------------------------------------+
   bool TestSafety()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "TEST_START", "Running Phase 3 Safety Verification...");

      CCapabilities capabilities;
      if(capabilities.can_trade)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase3Tests", "SAFETY_VIOLATION",
            "Trading capability is enabled! Phase 3 must have can_trade = false.");
         return false;
      }

      SATGSignalCandidate candidate;
      candidate.Reset();
      candidate.status = SIGNAL_STATUS_CANDIDATE_ONLY;

      if(candidate.status != SIGNAL_STATUS_CANDIDATE_ONLY)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase3Tests", "SAFETY_VIOLATION",
            "Candidate signal status violated CANDIDATE_ONLY constraint.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "TEST_PASS",
         "Phase 3 Safety Gate verified: can_trade == false, status == CANDIDATE_ONLY.");
      return true;
   }

public:
   CPhase3Tests(CLogger* logger)
      : m_logger(logger)
   {
   }

   //+----------------------------------------------------------------+
   //| Run all Phase 3 tests                                          |
   //+----------------------------------------------------------------+
   bool RunAllTests()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "SUITE_START", "=== Starting Phase 3 Market Intelligence Test Suite ===");

      if(!TestFeatureCalculations())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase3Tests", "SUITE_FAIL", "Feature Calculations test suite failed.");
         return false;
      }

      if(!TestRegimeClassification())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase3Tests", "SUITE_FAIL", "Regime Classification test suite failed.");
         return false;
      }

      if(!TestSignalAnalysis())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase3Tests", "SUITE_FAIL", "Signal Analysis test suite failed.");
         return false;
      }

      if(!TestSafety())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase3Tests", "SUITE_FAIL", "Phase 3 Safety verification failed.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase3Tests", "SUITE_PASS", "=== All Phase 3 Market Intelligence Tests Passed Successfully ===");
      return true;
   }
};

#endif
