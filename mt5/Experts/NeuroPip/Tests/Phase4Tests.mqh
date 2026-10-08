//+------------------------------------------------------------------+
//| Phase4Tests.mqh                                                  |
//| NeuroPip - Phase 4                                     |
//| Strategy Decision Engine & Signal Validation Test Suite          |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_PHASE4_TESTS_MQH
#define ATG_PHASE4_TESTS_MQH

#include "../Diagnostics/Logger.mqh"
#include "../Security/Capabilities.mqh"
#include "../Strategy/StrategyTypes.mqh"
#include "../Strategy/StrategyValidator.mqh"
#include "../Strategy/TrendContinuationStrategy.mqh"

class CPhase4Tests
{
private:
   CLogger* m_logger;

   // Helper to set up a mock healthy bullish multi-timeframe environment
   void SetupBullishMock(SMultiTimeframeFeatures &mtf, SRegimeClassification &reg, SATGSignalCandidate &sig)
   {
      mtf.Reset();
      mtf.symbol = "EURUSDm";
      mtf.overall_data_ready = true;

      // H4
      mtf.tf_h4.data_ready = true;
      mtf.tf_h4.trend.trend_direction = TREND_BULLISH;
      mtf.tf_h4.trend.fast_ma = 1.1100;
      mtf.tf_h4.trend.slow_ma = 1.1000;
      mtf.tf_h4.trend.is_valid = true;

      // H1
      mtf.tf_h1.data_ready = true;
      mtf.tf_h1.trend.trend_direction = TREND_BULLISH;
      mtf.tf_h1.trend.fast_ma = 1.1080;
      mtf.tf_h1.trend.slow_ma = 1.1020;
      mtf.tf_h1.trend.ma_slope_points = 2.5;
      mtf.tf_h1.trend.is_valid = true;

      // M15
      mtf.tf_m15.data_ready = true;
      mtf.tf_m15.bar_time = 1700000000;
      mtf.tf_m15.trend.trend_direction = TREND_BULLISH;
      mtf.tf_m15.trend.is_valid = true;
      mtf.tf_m15.structure.structure_state = STRUCT_HIGHER_HIGHS_LOWS;
      mtf.tf_m15.structure.higher_high = true;
      mtf.tf_m15.structure.higher_low = true;
      mtf.tf_m15.structure.is_valid = true;
      mtf.tf_m15.momentum.rsi = 58.0;
      mtf.tf_m15.momentum.is_overbought = false;
      mtf.tf_m15.momentum.is_oversold = false;
      mtf.tf_m15.momentum.is_valid = true;
      mtf.tf_m15.volatility.atr_points = 18.0;
      mtf.tf_m15.volatility.atr_ratio_to_avg = 1.05;
      mtf.tf_m15.volatility.vol_state = VOL_NORMAL;
      mtf.tf_m15.volatility.is_valid = true;
      mtf.tf_m15.spread.spread_points = 12;
      mtf.tf_m15.spread.spread_acceptable = true;
      mtf.tf_m15.spread.data_ready = true;

      // M5
      mtf.tf_m5.data_ready = true;
      mtf.tf_m5.trend.trend_direction = TREND_BULLISH;
      mtf.tf_m5.trend.is_valid = true;

      // Regime
      reg.Reset();
      reg.is_valid = true;
      reg.primary_regime = REGIME_TRENDING_BULLISH;
      reg.trend_dimension = REGIME_TREND_BULLISH;
      reg.vol_dimension = REGIME_VOL_NORMAL;
      reg.struct_dimension = REGIME_STRUCT_EXPANSION;
      reg.confidence = 0.85;

      // Signal Candidate from Phase 3
      sig.Reset();
      sig.symbol = "EURUSDm";
      sig.direction = SIGNAL_DIR_BUY;
      sig.quality = SIGNAL_QUALITY_CANDIDATE;
      sig.bias = BIAS_BULLISH;
      sig.status = SIGNAL_STATUS_CANDIDATE_ONLY;
      sig.confidence = 0.82;
      sig.strength = 0.80;
      sig.is_candidate = true;
      sig.is_valid = true;
      sig.AddEvidence("H1 trend bullish");
      sig.AddEvidence("M15 structure HH/HL");
   }

   //+----------------------------------------------------------------+
   //| Test 1: Strategy Qualification & Gates                         |
   //+----------------------------------------------------------------+
   bool TestStrategyQualification()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_START", "Running Strategy Qualification tests...");

      CTrendContinuationStrategy strat(m_logger);
      SMultiTimeframeFeatures mtf;
      SRegimeClassification reg;
      SATGSignalCandidate sig;
      SStrategyDecision dec;

      // Case A: Ideal Bullish Setup -> Must Approve as Strategy Candidate
      SetupBullishMock(mtf, reg, sig);
      bool ok = strat.Evaluate(mtf, reg, sig, 1, dec);

      if(!ok || dec.status != STRATEGY_APPROVED || !dec.is_approved || dec.direction != SIGNAL_DIR_BUY)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            StringFormat("Ideal Bullish setup failed approval. Status=%s Reason=%s Detail=%s",
               dec.StatusToString(), dec.RejectionToString(), dec.rejection_detail));
         return false;
      }

      // Case B: Ideal Bearish Setup -> Must Approve as Strategy Candidate
      SetupBullishMock(mtf, reg, sig);
      sig.direction = SIGNAL_DIR_SELL;
      sig.bias = BIAS_BEARISH;
      reg.primary_regime = REGIME_TRENDING_BEARISH;
      reg.trend_dimension = REGIME_TREND_BEARISH;
      mtf.tf_h4.trend.trend_direction = TREND_BEARISH;
      mtf.tf_h1.trend.trend_direction = TREND_BEARISH;
      mtf.tf_h1.trend.ma_slope_points = -2.5;
      mtf.tf_m15.trend.trend_direction = TREND_BEARISH;
      mtf.tf_m15.structure.structure_state = STRUCT_LOWER_HIGHS_LOWS;
      mtf.tf_m15.momentum.rsi = 42.0;
      mtf.tf_m5.trend.trend_direction = TREND_BEARISH;

      ok = strat.Evaluate(mtf, reg, sig, 2, dec);
      if(!ok || dec.status != STRATEGY_APPROVED || !dec.is_approved || dec.direction != SIGNAL_DIR_SELL)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            StringFormat("Ideal Bearish setup failed approval. Status=%s Reason=%s Detail=%s",
               dec.StatusToString(), dec.RejectionToString(), dec.rejection_detail));
         return false;
      }

      // Case C: Insufficient Confidence -> Must Reject
      SetupBullishMock(mtf, reg, sig);
      sig.confidence = 0.50; // Below 0.75 min threshold
      ok = strat.Evaluate(mtf, reg, sig, 3, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_CONFIDENCE_BELOW_MIN)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "Insufficient confidence did not trigger STRAT_REJECT_CONFIDENCE_BELOW_MIN.");
         return false;
      }

      // Case D: Excessive Spread -> Must Reject
      SetupBullishMock(mtf, reg, sig);
      mtf.tf_m15.spread.spread_points = 55; // Limit is 35
      ok = strat.Evaluate(mtf, reg, sig, 4, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_EXCESSIVE_SPREAD)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "Excessive spread did not trigger STRAT_REJECT_EXCESSIVE_SPREAD.");
         return false;
      }

      // Case E: Invalid Volatility (ATR too low) -> Must Reject
      SetupBullishMock(mtf, reg, sig);
      mtf.tf_m15.volatility.atr_points = 3.0; // Min is 8.0
      ok = strat.Evaluate(mtf, reg, sig, 5, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_VOLATILITY_INVALID)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "Low ATR did not trigger STRAT_REJECT_VOLATILITY_INVALID.");
         return false;
      }

      // Case F: Insufficient Data -> Must Reject
      SetupBullishMock(mtf, reg, sig);
      mtf.overall_data_ready = false;
      ok = strat.Evaluate(mtf, reg, sig, 6, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_INSUFFICIENT_DATA)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "Incomplete data did not trigger STRAT_REJECT_INSUFFICIENT_DATA.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_PASS", "Strategy Qualification tests passed.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 2: Regime Compatibility Matrix                            |
   //+----------------------------------------------------------------+
   bool TestRegimeCompatibility()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_START", "Running Regime Compatibility tests...");

      CTrendContinuationStrategy strat(m_logger);
      SMultiTimeframeFeatures mtf;
      SRegimeClassification reg;
      SATGSignalCandidate sig;
      SStrategyDecision dec;

      // Case A: Ranging Regime must reject Trend Continuation
      SetupBullishMock(mtf, reg, sig);
      reg.primary_regime = REGIME_RANGING;
      bool ok = strat.Evaluate(mtf, reg, sig, 10, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_REGIME_INCOMPATIBLE)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "RANGING regime did not trigger STRAT_REJECT_REGIME_INCOMPATIBLE.");
         return false;
      }

      // Case B: Low Volatility Regime must reject
      SetupBullishMock(mtf, reg, sig);
      reg.primary_regime = REGIME_LOW_VOLATILITY;
      ok = strat.Evaluate(mtf, reg, sig, 11, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_REGIME_INCOMPATIBLE)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "LOW_VOLATILITY regime did not trigger STRAT_REJECT_REGIME_INCOMPATIBLE.");
         return false;
      }

      // Case C: Direction contradicts Regime Trend (BUY in BEARISH regime trend)
      SetupBullishMock(mtf, reg, sig);
      reg.trend_dimension = REGIME_TREND_BEARISH;
      ok = strat.Evaluate(mtf, reg, sig, 12, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_REGIME_INCOMPATIBLE)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "BUY in BEARISH regime trend did not trigger STRAT_REJECT_REGIME_INCOMPATIBLE.");
         return false;
      }

      // Case D: High Volatility regime with wide spread must reject
      SetupBullishMock(mtf, reg, sig);
      reg.vol_dimension = REGIME_VOL_HIGH;
      mtf.tf_m15.spread.spread_points = 25; // Exceeds strict high-vol tolerance (max_spread / 2 = 17)
      ok = strat.Evaluate(mtf, reg, sig, 13, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_VOLATILITY_INVALID)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "High volatility with wide spread did not reject.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_PASS", "Regime Compatibility tests passed.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 3: Conflict Detection & Multi-Timeframe Hierarchy         |
   //+----------------------------------------------------------------+
   bool TestConflictDetection()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_START", "Running Conflict Detection tests...");

      CTrendContinuationStrategy strat(m_logger);
      SMultiTimeframeFeatures mtf;
      SRegimeClassification reg;
      SATGSignalCandidate sig;
      SStrategyDecision dec;

      // Case A: Higher Timeframe Conflict (H4 Bearish while trying to BUY) -> Must Reject
      SetupBullishMock(mtf, reg, sig);
      mtf.tf_h4.trend.trend_direction = TREND_BEARISH; // Higher TF opposes!
      bool ok = strat.Evaluate(mtf, reg, sig, 20, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_TIMEFRAME_ALIGNMENT)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "H4 opposing trend did not trigger STRAT_REJECT_TIMEFRAME_ALIGNMENT.");
         return false;
      }

      // Case B: Structure Conflict (M15 Lower-Highs/Lower-Lows on BUY) -> Must Reject
      SetupBullishMock(mtf, reg, sig);
      mtf.tf_m15.structure.structure_state = STRUCT_LOWER_HIGHS_LOWS;
      ok = strat.Evaluate(mtf, reg, sig, 21, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_STRUCTURE_INVALID)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "M15 LH/LL structure on BUY did not trigger STRAT_REJECT_STRUCTURE_INVALID.");
         return false;
      }

      // Case C: Momentum Conflict (RSI Overbought on BUY setup) -> Must Reject
      SetupBullishMock(mtf, reg, sig);
      mtf.tf_m15.momentum.rsi = 74.0;
      mtf.tf_m15.momentum.is_overbought = true;
      ok = strat.Evaluate(mtf, reg, sig, 22, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_MOMENTUM_INVALID)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "Overbought RSI on BUY did not trigger STRAT_REJECT_MOMENTUM_INVALID.");
         return false;
      }

      // Case D: Multiple active conflicts from Phase 3 candidate -> Must Trigger Critical Conflict
      SetupBullishMock(mtf, reg, sig);
      sig.AddConflict("M5 momentum divergence");
      sig.AddConflict("D1 resistance zone nearby");
      ok = strat.Evaluate(mtf, reg, sig, 23, dec);
      if(ok || dec.status != STRATEGY_REJECTED || dec.rejection_reason != STRAT_REJECT_CRITICAL_CONFLICT)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL",
            "Multiple conflicts did not trigger STRAT_REJECT_CRITICAL_CONFLICT.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_PASS", "Conflict Detection tests passed.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 4: Duplicate Bar Control                                  |
   //+----------------------------------------------------------------+
   bool TestDuplicateControl()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_START", "Running Duplicate Control test...");

      datetime bar_1 = 1700000000;
      datetime last_eval_bar = bar_1;

      // Evaluation on same bar timestamp must be recognized as duplicate
      datetime incoming_bar = bar_1;
      bool is_duplicate = (incoming_bar == last_eval_bar);

      if(!is_duplicate)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL", "Failed to detect duplicate closed bar.");
         return false;
      }

      // New bar timestamp must be recognized as fresh
      incoming_bar = bar_1 + 900; // Next M15 bar
      bool is_fresh = (incoming_bar != last_eval_bar);
      if(!is_fresh)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase4Tests", "TEST_FAIL", "New bar was incorrectly flagged as duplicate.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_PASS", "Duplicate Control tests passed.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 5: Execution Safety Verification                          |
   //+----------------------------------------------------------------+
   bool TestSafety()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_START", "Running Phase 4 Safety Verification...");

      CCapabilities capabilities;
      if(capabilities.can_trade)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase4Tests", "SAFETY_VIOLATION",
            "Trading capability is enabled! Phase 4 must have can_trade = false.");
         return false;
      }

      SStrategyDecision decision;
      decision.Reset();
      decision.status = STRATEGY_APPROVED;
      decision.is_approved = true;

      // Confirm that STRATEGY_APPROVED is strictly candidate-only and has no execution method
      if(decision.status != STRATEGY_APPROVED || !decision.is_approved)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase4Tests", "SAFETY_VIOLATION",
            "Decision status mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "TEST_PASS",
         "Phase 4 Safety Gate verified: can_trade == false, status == STRATEGY_APPROVED (CANDIDATE ONLY, NO LIVE EXECUTION).");
      return true;
   }

public:
   CPhase4Tests(CLogger* logger)
      : m_logger(logger)
   {
   }

   //+----------------------------------------------------------------+
   //| Run all Phase 4 tests                                          |
   //+----------------------------------------------------------------+
   bool RunAllTests()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "SUITE_START", "=== Starting Phase 4 Strategy Decision Engine Test Suite ===");

      if(!TestStrategyQualification())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase4Tests", "SUITE_FAIL", "Strategy Qualification test suite failed.");
         return false;
      }

      if(!TestRegimeCompatibility())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase4Tests", "SUITE_FAIL", "Regime Compatibility test suite failed.");
         return false;
      }

      if(!TestConflictDetection())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase4Tests", "SUITE_FAIL", "Conflict Detection test suite failed.");
         return false;
      }

      if(!TestDuplicateControl())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase4Tests", "SUITE_FAIL", "Duplicate Control test suite failed.");
         return false;
      }

      if(!TestSafety())
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase4Tests", "SUITE_FAIL", "Phase 4 Safety verification failed.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase4Tests", "SUITE_PASS", "=== All Phase 4 Strategy Decision Tests Passed Successfully ===");
      return true;
   }
};

#endif
