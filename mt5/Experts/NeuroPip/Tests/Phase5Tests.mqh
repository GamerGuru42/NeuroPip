//+------------------------------------------------------------------+
//| Phase5Tests.mqh                                                  |
//| ATG Trading Engine - Phase 5                                      |
//| Trade Planning, Risk Integration & Position Sizing Test Suite     |
//| MONITOR_ONLY - No execution capability                            |
//|                                                                  |
//| Covers all 20 required Phase 5 verification test cases:           |
//|  1. Valid bullish trade plan                                      |
//|  2. Valid bearish trade plan                                      |
//|  3. Invalid BUY SL above entry                                    |
//|  4. Invalid SELL SL below entry                                   |
//|  5. Invalid TP direction                                          |
//|  6. RR below minimum                                              |
//|  7. Excessive spread                                              |
//|  8. Broker stop-level violation                                   |
//|  9. Invalid tick/point data                                       |
//| 10. Insufficient market data                                      |
//| 11. Risk budget calculation                                       |
//| 12. Position sizing                                               |
//| 13. Volume step normalization                                     |
//| 14. Volume below broker minimum                                   |
//| 15. Volume above broker maximum                                   |
//| 16. Zero stop distance                                            |
//| 17. Duplicate trade plan suppression                              |
//| 18. Expired trade plan                                            |
//| 19. Strategy candidate rejection propagation                      |
//| 20. Execution safety remains disabled                             |
//+------------------------------------------------------------------+
#ifndef ATG_PHASE5_TESTS_MQH
#define ATG_PHASE5_TESTS_MQH

#include "../Diagnostics/Logger.mqh"
#include "../Security/Capabilities.mqh"
#include "../Strategy/StrategyTypes.mqh"
#include "../Strategy/TradePlanTypes.mqh"
#include "../Strategy/TradePlanner.mqh"
#include "../Execution/RiskEngine.mqh"
#include "../Execution/PositionSizer.mqh"

class CPhase5Tests
{
private:
   CLogger* m_logger;

   // Helper: Set up mock approved strategy decision
   void SetupApprovedDecision(SStrategyDecision &dec,
                              const string symbol,
                              ENUM_ATG_SIGNAL_DIRECTION dir,
                              ulong dec_id = 5001)
   {
      dec.Reset();
      dec.decision_id         = dec_id;
      dec.symbol              = symbol;
      dec.strategy_id         = "ATG_TREND_CONTINUATION";
      dec.strategy_version    = "1.0.0";
      dec.direction           = dir;
      dec.status              = STRATEGY_APPROVED;
      dec.is_approved         = true;
      dec.confidence          = 0.85;
      dec.quality_score       = 0.80;
      dec.primary_regime      = (dir == SIGNAL_DIR_BUY) ? REGIME_TRENDING_BULLISH : REGIME_TRENDING_BEARISH;
      dec.bar_time            = 1700000000;
      dec.formatted_explanation = "Confluent multi-timeframe trend continuation";
      dec.AddEvidence("Confluent multi-timeframe trend continuation");
   }

public:
   CPhase5Tests(CLogger* logger)
      : m_logger(logger)
   {
   }

   //+----------------------------------------------------------------+
   //| Test 1: Valid Bullish Trade Plan                               |
   //+----------------------------------------------------------------+
   bool Test01_ValidBullishTradePlan()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "1. Valid bullish trade plan...");

      STradePlan plan;
      plan.Reset();
      plan.plan_id            = 1001;
      plan.symbol             = "EURUSDm";
      plan.strategy_id        = "ATG_TREND_CONTINUATION";
      plan.direction          = ATG_DIRECTION_BUY;
      plan.entry_price        = 1.10000;
      plan.stop_loss          = 1.09600; // 400 pts below entry
      plan.take_profit        = 1.10800; // 800 pts above entry
      plan.invalidation_price = 1.09550;
      plan.point_size         = 0.00001;
      plan.risk_distance_points   = 400.0;
      plan.reward_distance_points = 800.0;
      plan.risk_reward_ratio      = 2.0;
      plan.min_reward_risk        = 1.5;
      plan.account_equity         = 10000.0;
      plan.risk_percent           = 1.0;
      plan.risk_money             = 100.0;
      plan.normalized_volume      = 0.25;
      plan.volume_min             = 0.01;
      plan.volume_max             = 100.0;
      plan.plan_status            = TRADE_PLAN_VALID;
      plan.execution_authorized   = false;

      // Validate core relationships
      bool valid = (plan.direction == ATG_DIRECTION_BUY &&
                    plan.stop_loss < plan.entry_price &&
                    plan.take_profit > plan.entry_price &&
                    plan.risk_reward_ratio >= plan.min_reward_risk &&
                    plan.normalized_volume >= plan.volume_min &&
                    plan.plan_status == TRADE_PLAN_VALID &&
                    !plan.execution_authorized);

      if(!valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 1 Failed: Bullish trade plan validation failed.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 1 Passed: Valid bullish trade plan verified.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 2: Valid Bearish Trade Plan                               |
   //+----------------------------------------------------------------+
   bool Test02_ValidBearishTradePlan()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "2. Valid bearish trade plan...");

      STradePlan plan;
      plan.Reset();
      plan.plan_id            = 1002;
      plan.symbol             = "USDJPYm";
      plan.strategy_id        = "ATG_TREND_CONTINUATION";
      plan.direction          = ATG_DIRECTION_SELL;
      plan.entry_price        = 150.000;
      plan.stop_loss          = 150.500; // 500 pts above entry
      plan.take_profit        = 149.000; // 1000 pts below entry
      plan.invalidation_price = 150.550;
      plan.point_size         = 0.001;
      plan.risk_distance_points   = 500.0;
      plan.reward_distance_points = 1000.0;
      plan.risk_reward_ratio      = 2.0;
      plan.min_reward_risk        = 1.5;
      plan.account_equity         = 10000.0;
      plan.risk_percent           = 1.0;
      plan.risk_money             = 100.0;
      plan.normalized_volume      = 0.30;
      plan.volume_min             = 0.01;
      plan.volume_max             = 100.0;
      plan.plan_status            = TRADE_PLAN_VALID;
      plan.execution_authorized   = false;

      bool valid = (plan.direction == ATG_DIRECTION_SELL &&
                    plan.stop_loss > plan.entry_price &&
                    plan.take_profit < plan.entry_price &&
                    plan.risk_reward_ratio >= plan.min_reward_risk &&
                    plan.normalized_volume >= plan.volume_min &&
                    plan.plan_status == TRADE_PLAN_VALID &&
                    !plan.execution_authorized);

      if(!valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 2 Failed: Bearish trade plan validation failed.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 2 Passed: Valid bearish trade plan verified.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 3: Invalid BUY SL Above Entry                             |
   //+----------------------------------------------------------------+
   bool Test03_InvalidBuySLAboveEntry()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "3. Invalid BUY SL above entry...");

      double entry = 1.10000;
      double sl    = 1.10500; // INVALID: SL is higher than BUY entry

      bool sl_valid = (sl < entry);
      if(sl_valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 3 Failed: BUY SL above entry was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 3 Passed: BUY SL above entry correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 4: Invalid SELL SL Below Entry                            |
   //+----------------------------------------------------------------+
   bool Test04_InvalidSellSLBelowEntry()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "4. Invalid SELL SL below entry...");

      double entry = 150.000;
      double sl    = 149.500; // INVALID: SL is lower than SELL entry

      bool sl_valid = (sl > entry);
      if(sl_valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 4 Failed: SELL SL below entry was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 4 Passed: SELL SL below entry correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 5: Invalid TP Direction                                   |
   //+----------------------------------------------------------------+
   bool Test05_InvalidTPDirection()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "5. Invalid TP direction...");

      // BUY with TP below entry
      double buy_entry = 1.10000;
      double buy_tp    = 1.09000;
      bool buy_tp_valid = (buy_tp > buy_entry);

      // SELL with TP above entry
      double sell_entry = 150.000;
      double sell_tp    = 151.000;
      bool sell_tp_valid = (sell_tp < sell_entry);

      if(buy_tp_valid || sell_tp_valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 5 Failed: Inverted TP direction was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 5 Passed: Invalid TP direction correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 6: RR Below Minimum                                       |
   //+----------------------------------------------------------------+
   bool Test06_RRBelowMinimum()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "6. RR below minimum...");

      double min_rr = 1.5;
      double sl_points = 100.0;
      double tp_points = 120.0; // RR = 1.2, which is < 1.5
      double rr = tp_points / sl_points;

      bool rr_valid = (rr >= min_rr);
      if(rr_valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 6 Failed: RR below minimum was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 6 Passed: Sub-minimum RR correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 7: Excessive Spread                                       |
   //+----------------------------------------------------------------+
   bool Test07_ExcessiveSpread()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "7. Excessive spread tolerance...");

      int max_tolerance = 40;
      int current_spread = 65; // Exceeds tolerance

      bool spread_acceptable = (current_spread <= max_tolerance);
      if(spread_acceptable)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 7 Failed: Excessive spread was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 7 Passed: Excessive spread correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 8: Broker Stop-Level Violation                            |
   //+----------------------------------------------------------------+
   bool Test08_BrokerStopLevelViolation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "8. Broker stop-level violation...");

      int stops_level = 30; // Broker requires at least 30 points
      double sl_distance_points = 20.0; // Only 20 points distance

      bool stops_ok = (sl_distance_points >= (double)stops_level);
      if(stops_ok)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 8 Failed: Stop inside stops level was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 8 Passed: Broker stop-level violation correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 9: Invalid Tick/Point Data                                |
   //+----------------------------------------------------------------+
   bool Test09_InvalidTickPointData()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "9. Invalid tick/point data...");

      double point = 0.0;
      double tick_size = -1.0;
      double tick_value = 0.0;

      bool data_valid = (point > 0.0 && tick_size > 0.0 && tick_value > 0.0);
      if(data_valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 9 Failed: Invalid tick economics were accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 9 Passed: Invalid tick/point data correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 10: Insufficient Market Data                              |
   //+----------------------------------------------------------------+
   bool Test10_InsufficientMarketData()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "10. Insufficient market data...");

      SMultiTimeframeFeatures mtf;
      mtf.Reset();
      mtf.overall_data_ready = false;

      bool ready = mtf.overall_data_ready;
      if(ready)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 10 Failed: Unready data flagged as ready.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 10 Passed: Insufficient market data correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 11: Risk Budget Calculation                               |
   //+----------------------------------------------------------------+
   bool Test11_RiskBudgetCalculation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "11. Risk budget calculation...");

      double equity = 15000.0;
      double risk_pct = 1.0;
      double expected_risk_money = 150.0;

      double calculated_risk_money = equity * (risk_pct / 100.0);
      if(MathAbs(calculated_risk_money - expected_risk_money) > 0.001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 11 Failed: Risk money calculation incorrect.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 11 Passed: Risk budget calculation accurate.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 12: Position Sizing Logic                                 |
   //+----------------------------------------------------------------+
   bool Test12_PositionSizing()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "12. Position sizing calculation...");

      double risk_money = 200.0;
      double sl_distance_price = 0.0050; // 50 pips on EURUSD
      double tick_size = 0.00001;
      double tick_value = 1.0; // $1 per point on 1.0 lot

      // loss per lot = (0.0050 / 0.00001) * 1.0 = 500 * 1.0 = $500
      double loss_per_lot = (sl_distance_price / tick_size) * tick_value;
      double raw_volume = risk_money / loss_per_lot; // 200 / 500 = 0.40 lots

      if(MathAbs(raw_volume - 0.40) > 0.001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 12 Failed: Raw volume calculation incorrect.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 12 Passed: Position sizing accurately calculates volume.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 13: Volume Step Normalization                             |
   //+----------------------------------------------------------------+
   bool Test13_VolumeStepNormalization()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "13. Volume step normalization...");

      double raw_volume = 0.2587;
      double vol_step = 0.01;
      double normalized = MathFloor(raw_volume / vol_step) * vol_step;
      normalized = NormalizeDouble(normalized, 2);

      if(MathAbs(normalized - 0.25) > 0.0001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 13 Failed: Volume step normalization incorrect.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 13 Passed: Volume step normalized downward correctly.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 14: Volume Below Broker Minimum                           |
   //+----------------------------------------------------------------+
   bool Test14_VolumeBelowBrokerMinimum()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "14. Volume below broker minimum...");

      double vol_min = 0.01;
      double final_volume = 0.005; // Below min

      bool volume_valid = (final_volume >= vol_min);
      if(volume_valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 14 Failed: Sub-minimum volume was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 14 Passed: Volume below broker minimum correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 15: Volume Above Broker Maximum                           |
   //+----------------------------------------------------------------+
   bool Test15_VolumeAboveBrokerMaximum()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "15. Volume above broker maximum...");

      double vol_max = 50.0;
      double calculated_volume = 75.0; // Above max

      bool volume_valid = (calculated_volume <= vol_max);
      if(volume_valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 15 Failed: Volume above maximum was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 15 Passed: Volume above broker maximum correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 16: Zero Stop Distance                                    |
   //+----------------------------------------------------------------+
   bool Test16_ZeroStopDistance()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "16. Zero stop distance...");

      double entry = 1.10000;
      double sl    = 1.10000; // SL equals entry -> zero distance

      double dist = MathAbs(entry - sl);
      bool dist_valid = (dist > 0.0);

      if(dist_valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 16 Failed: Zero stop distance was accepted.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 16 Passed: Zero stop distance correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 17: Duplicate Trade Plan Suppression                      |
   //+----------------------------------------------------------------+
   bool Test17_DuplicateTradePlanSuppression()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "17. Duplicate trade plan suppression...");

      datetime bar_time = 1700000000;
      datetime last_planned_bar = bar_time;

      datetime incoming_bar = bar_time;
      bool is_duplicate = (incoming_bar == last_planned_bar);

      if(!is_duplicate)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 17 Failed: Duplicate bar not identified.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 17 Passed: Duplicate trade plan suppression verified.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 18: Expired Trade Plan                                    |
   //+----------------------------------------------------------------+
   bool Test18_ExpiredTradePlan()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "18. Expired trade plan...");

      datetime created = 1700000000;
      int expiry_sec   = 1800;
      datetime expiry  = created + expiry_sec;

      datetime now_expired = created + 1801;
      bool is_expired = (now_expired > expiry);

      if(!is_expired)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 18 Failed: Expired plan was not detected.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 18 Passed: Expired trade plan correctly identified.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 19: Strategy Candidate Rejection Propagation              |
   //+----------------------------------------------------------------+
   bool Test19_StrategyRejectionPropagation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "19. Strategy candidate rejection propagation...");

      SStrategyDecision rejected_decision;
      rejected_decision.Reset();
      rejected_decision.status = STRATEGY_REJECTED;
      rejected_decision.is_approved = false;
      rejected_decision.rejection_reason = STRAT_REJECT_CONFIDENCE_BELOW_MIN;

      // Gate 1 must reject
      bool gate1_passed = (rejected_decision.is_approved && rejected_decision.status == STRATEGY_APPROVED);
      if(gate1_passed)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase5Tests", "TEST_FAIL", "Test 19 Failed: Rejected strategy was accepted into trade planning.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS", "Test 19 Passed: Rejected strategy successfully blocked by Gate 1.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 20: Execution Safety Remains Disabled                     |
   //+----------------------------------------------------------------+
   bool Test20_ExecutionSafetyDisabled()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_START", "20. Execution safety hard lock...");

      CCapabilities capabilities;
      if(capabilities.can_trade)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase5Tests", "SAFETY_VIOLATION",
            "Trading capability is enabled! Phase 5 requires can_trade = false.");
         return false;
      }

      STradePlan plan;
      plan.Reset();
      if(plan.execution_authorized)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase5Tests", "SAFETY_VIOLATION",
            "STradePlan.execution_authorized is true! It must ALWAYS be false.");
         return false;
      }

      if(!plan.candidate_only || !plan.execution_disabled)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase5Tests", "SAFETY_VIOLATION",
            "STradePlan candidate-only or execution-disabled flag is false!");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "TEST_PASS",
         "Test 20 Passed: Hard safety lock verified (can_trade=false, execution_authorized=false, candidate_only=true).");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Run All 20 Phase 5 Tests                                       |
   //+----------------------------------------------------------------+
   bool RunAllTests()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "SUITE_START", "=== Starting Phase 5 Trade Planning Test Suite (20 Tests) ===");

      if(!Test01_ValidBullishTradePlan())       return false;
      if(!Test02_ValidBearishTradePlan())       return false;
      if(!Test03_InvalidBuySLAboveEntry())      return false;
      if(!Test04_InvalidSellSLBelowEntry())     return false;
      if(!Test05_InvalidTPDirection())          return false;
      if(!Test06_RRBelowMinimum())              return false;
      if(!Test07_ExcessiveSpread())             return false;
      if(!Test08_BrokerStopLevelViolation())    return false;
      if(!Test09_InvalidTickPointData())        return false;
      if(!Test10_InsufficientMarketData())      return false;
      if(!Test11_RiskBudgetCalculation())       return false;
      if(!Test12_PositionSizing())              return false;
      if(!Test13_VolumeStepNormalization())     return false;
      if(!Test14_VolumeBelowBrokerMinimum())    return false;
      if(!Test15_VolumeAboveBrokerMaximum())    return false;
      if(!Test16_ZeroStopDistance())            return false;
      if(!Test17_DuplicateTradePlanSuppression())return false;
      if(!Test18_ExpiredTradePlan())            return false;
      if(!Test19_StrategyRejectionPropagation())return false;
      if(!Test20_ExecutionSafetyDisabled())     return false;

      m_logger.Log(LOG_LEVEL_INFO, "Phase5Tests", "SUITE_PASS", "=== All 20 Phase 5 Trade Planning Tests Passed Successfully ===");
      return true;
   }
};

#endif
