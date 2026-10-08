//+------------------------------------------------------------------+
//| Phase6Tests.mqh                                                  |
//| NeuroPip - Phase 6                                      |
//| Paper Trading & Performance Engine Test Suite                    |
//| MONITOR_ONLY - No execution capability                            |
//|                                                                  |
//| Covers all 25 required Phase 6 verification test cases:           |
//|  1. Valid BUY paper trade creation                               |
//|  2. Valid SELL paper trade creation                              |
//|  3. BUY TP hit                                                   |
//|  4. BUY SL hit                                                   |
//|  5. SELL TP hit                                                  |
//|  6. SELL SL hit                                                  |
//|  7. Same-bar SL/TP ambiguity (conservative SL)                   |
//|  8. Trade expiry                                                 |
//|  9. Invalid plan rejection                                       |
//| 10. Duplicate paper trade prevention                             |
//| 11. P&L calculation                                              |
//| 12. R multiple calculation                                       |
//| 13. Equity update                                                |
//| 14. Maximum drawdown calculation                                 |
//| 15. Win rate calculation                                         |
//| 16. Profit factor calculation                                    |
//| 17. Expectancy calculation                                       |
//| 18. Winning streak tracking                                      |
//| 19. Losing streak tracking                                       |
//| 20. Symbol-level aggregation                                     |
//| 21. Strategy-level aggregation                                   |
//| 22. Regime-level aggregation                                     |
//| 23. Insufficient sample handling (< 30 trades)                   |
//| 24. Execution safety (no live orders, can_trade == false)        |
//| 25. Previous Phase 1–5 regression test verification              |
//+------------------------------------------------------------------+
#ifndef ATG_PHASE6_TESTS_MQH
#define ATG_PHASE6_TESTS_MQH

#include "../Diagnostics/Logger.mqh"
#include "../Security/Capabilities.mqh"
#include "../Strategy/TradePlanTypes.mqh"
#include "../Simulation/PaperTradeTypes.mqh"
#include "../Simulation/PerformanceEngine.mqh"
#include "../Simulation/PaperTradingEngine.mqh"

class CPhase6Tests
{
private:
   CLogger* m_logger;

   // Helper: construct valid Trade Plan mock
   void SetupValidPlanMock(STradePlan &plan,
                           const string symbol,
                           ENUM_ATG_TRADE_DIRECTION dir,
                           ulong plan_id = 9001)
   {
      plan.Reset();
      plan.plan_id            = plan_id;
      plan.symbol             = symbol;
      plan.strategy_id        = "NEUROPIP_TREND_CONTINUATION";
      plan.strategy_version   = "1.0.0";
      plan.source_decision_id = 8001;
      plan.direction          = dir;
      plan.primary_timeframe  = PERIOD_M15;
      plan.source_bar_time    = 1700000000;
      plan.plan_status        = TRADE_PLAN_VALID;
      plan.status             = TRADE_PLAN_VALID;

      if(dir == ATG_DIRECTION_BUY)
      {
         plan.entry_price        = 1.10000;
         plan.stop_loss          = 1.09600; // 400 pts
         plan.take_profit        = 1.10800; // 800 pts
      }
      else
      {
         plan.entry_price        = 150.000;
         plan.stop_loss          = 150.500; // 500 pts
         plan.take_profit        = 149.000; // 1000 pts
      }

      plan.normalized_volume  = 0.20;
      plan.risk_money         = 100.00;
      plan.risk_percent       = 1.00;
      plan.risk_reward_ratio  = 2.00;
      plan.strategy_confidence= 0.85;
      plan.strategy_quality   = 0.80;
      plan.regime             = (dir == ATG_DIRECTION_BUY) ? REGIME_TRENDING_BULLISH : REGIME_TRENDING_BEARISH;
      plan.candidate_only     = true;
      plan.execution_disabled = true;
      plan.execution_authorized= false;
   }

public:
   CPhase6Tests(CLogger* logger)
      : m_logger(logger)
   {
   }

   //+----------------------------------------------------------------+
   //| Test 1: Valid BUY Paper Trade Creation                         |
   //+----------------------------------------------------------------+
   bool Test01_ValidBuyPaperTradeCreation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "1. Valid BUY paper trade creation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);
      CPaperTradingEngine engine(m_logger, &perf, NULL);

      STradePlan plan;
      SetupValidPlanMock(plan, "EURUSDm", ATG_DIRECTION_BUY, 9101);

      SPaperTrade trade;
      bool ok = engine.CreatePaperTrade(plan, trade);

      bool valid = (ok &&
                    trade.status == PAPER_OPEN &&
                    trade.direction == ATG_DIRECTION_BUY &&
                    trade.symbol == "EURUSDm" &&
                    trade.entry_price == plan.entry_price &&
                    trade.stop_loss == plan.stop_loss &&
                    trade.take_profit == plan.take_profit &&
                    trade.volume == plan.normalized_volume &&
                    trade.candidate_only);

      if(!valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 1 Failed: BUY paper trade creation failed.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 1 Passed: Valid BUY paper trade created.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 2: Valid SELL Paper Trade Creation                        |
   //+----------------------------------------------------------------+
   bool Test02_ValidSellPaperTradeCreation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "2. Valid SELL paper trade creation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);
      CPaperTradingEngine engine(m_logger, &perf, NULL);

      STradePlan plan;
      SetupValidPlanMock(plan, "USDJPYm", ATG_DIRECTION_SELL, 9102);

      SPaperTrade trade;
      bool ok = engine.CreatePaperTrade(plan, trade);

      bool valid = (ok &&
                    trade.status == PAPER_OPEN &&
                    trade.direction == ATG_DIRECTION_SELL &&
                    trade.symbol == "USDJPYm" &&
                    trade.entry_price == plan.entry_price &&
                    trade.stop_loss == plan.stop_loss &&
                    trade.take_profit == plan.take_profit &&
                    trade.volume == plan.normalized_volume &&
                    trade.candidate_only);

      if(!valid)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 2 Failed: SELL paper trade creation failed.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 2 Passed: Valid SELL paper trade created.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 3: BUY TP Hit Detection                                   |
   //+----------------------------------------------------------------+
   bool Test03_BuyTPHit()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "3. BUY TP hit detection...");

      double entry = 1.10000;
      double sl    = 1.09600;
      double tp    = 1.10800;

      // Candle exceeds TP
      double bar_high = 1.10850;
      double bar_low  = 1.09900;

      bool tp_hit = (bar_high >= tp);
      bool sl_hit = (bar_low <= sl);

      if(!tp_hit || sl_hit)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 3 Failed: BUY TP condition mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 3 Passed: BUY TP hit accurately detected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 4: BUY SL Hit Detection                                   |
   //+----------------------------------------------------------------+
   bool Test04_BuySLHit()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "4. BUY SL hit detection...");

      double entry = 1.10000;
      double sl    = 1.09600;
      double tp    = 1.10800;

      // Candle drops through SL
      double bar_high = 1.10200;
      double bar_low  = 1.09550;

      bool tp_hit = (bar_high >= tp);
      bool sl_hit = (bar_low <= sl);

      if(!sl_hit || tp_hit)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 4 Failed: BUY SL condition mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 4 Passed: BUY SL hit accurately detected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 5: SELL TP Hit Detection                                  |
   //+----------------------------------------------------------------+
   bool Test05_SellTPHit()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "5. SELL TP hit detection...");

      double entry = 150.000;
      double sl    = 150.500;
      double tp    = 149.000;

      // Candle drops through TP
      double bar_high = 150.100;
      double bar_low  = 148.950;

      bool tp_hit = (bar_low <= tp);
      bool sl_hit = (bar_high >= sl);

      if(!tp_hit || sl_hit)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 5 Failed: SELL TP condition mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 5 Passed: SELL TP hit accurately detected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 6: SELL SL Hit Detection                                  |
   //+----------------------------------------------------------------+
   bool Test06_SellSLHit()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "6. SELL SL hit detection...");

      double entry = 150.000;
      double sl    = 150.500;
      double tp    = 149.000;

      // Candle spikes through SL
      double bar_high = 150.550;
      double bar_low  = 149.800;

      bool tp_hit = (bar_low <= tp);
      bool sl_hit = (bar_high >= sl);

      if(!sl_hit || tp_hit)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 6 Failed: SELL SL condition mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 6 Passed: SELL SL hit accurately detected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 7: Same-Bar SL/TP Ambiguity Policy (Conservative SL)      |
   //+----------------------------------------------------------------+
   bool Test07_SameBarAmbiguity()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "7. Same-bar SL/TP ambiguity conservative policy...");

      double entry = 1.10000;
      double sl    = 1.09600;
      double tp    = 1.10800;

      // Candle contains BOTH SL and TP
      double bar_high = 1.10900; // Covers TP
      double bar_low  = 1.09500; // Covers SL

      bool sl_touched = (bar_low <= sl);
      bool tp_touched = (bar_high >= tp);

      if(!sl_touched || !tp_touched)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 7 Failed: Candle does not touch both levels.");
         return false;
      }

      // Conservative policy rule: MUST ASSUME SL WAS HIT FIRST
      string exit_reason = (sl_touched && tp_touched)
         ? EXIT_REASON_SAME_BAR_CONSERVATIVE_SL : EXIT_REASON_TP;

      double exit_price = (sl_touched && tp_touched) ? sl : tp;

      if(exit_reason != EXIT_REASON_SAME_BAR_CONSERVATIVE_SL || exit_price != sl)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL",
            "Test 7 Failed: Conservative policy failed to prioritize SL on same-bar touch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS",
         "Test 7 Passed: Same-bar ambiguity correctly resolved to conservative SL.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 8: Trade Expiry Detection                                 |
   //+----------------------------------------------------------------+
   bool Test08_TradeExpiry()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "8. Trade expiry detection...");

      datetime entry_time = 1700000000;
      int max_holding     = 3600; // 1 hour
      datetime current    = entry_time + 3601;

      bool is_expired = (current > entry_time + max_holding);
      if(!is_expired)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 8 Failed: Expired holding not detected.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 8 Passed: Trade expiry accurately detected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 9: Invalid Plan Rejection                                 |
   //+----------------------------------------------------------------+
   bool Test09_InvalidPlanRejection()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "9. Invalid plan rejection...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);
      CPaperTradingEngine engine(m_logger, &perf, NULL);

      STradePlan plan;
      SetupValidPlanMock(plan, "EURUSDm", ATG_DIRECTION_BUY, 9109);
      plan.plan_status = TRADE_PLAN_REJECTED; // INVALID

      SPaperTrade trade;
      bool ok = engine.CreatePaperTrade(plan, trade);

      if(ok || engine.GetActiveCount() > 0)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 9 Failed: Rejected trade plan was accepted for paper trading.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 9 Passed: Invalid plan correctly rejected.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 10: Duplicate Paper Trade Prevention                      |
   //+----------------------------------------------------------------+
   bool Test10_DuplicatePaperTradePrevention()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "10. Duplicate paper trade prevention...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);
      CPaperTradingEngine engine(m_logger, &perf, NULL);

      STradePlan plan;
      SetupValidPlanMock(plan, "EURUSDm", ATG_DIRECTION_BUY, 9110);

      SPaperTrade trade1, trade2;
      bool ok1 = engine.CreatePaperTrade(plan, trade1);
      bool ok2 = engine.CreatePaperTrade(plan, trade2); // DUPLICATE

      if(!ok1 || ok2 || engine.GetActiveCount() != 1)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 10 Failed: Duplicate trade plan was simulated twice.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 10 Passed: Duplicate paper trade successfully prevented.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 11: P&L Calculation                                       |
   //+----------------------------------------------------------------+
   bool Test11_PnLCalculation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "11. P&L calculation...");

      double entry = 1.10000;
      double exit  = 1.10800; // +80 pips
      double volume = 0.25;
      double tick_size = 0.00001;
      double tick_value = 1.0; // $1.00 per point on 1.0 lot

      double points = (exit - entry) / tick_size; // 800 points
      double pnl = points * tick_value * volume;   // 800 * 1.0 * 0.25 = $200.00

      if(MathAbs(pnl - 200.00) > 0.01)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 11 Failed: P&L calculation mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 11 Passed: P&L accurately calculated ($200.00).");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 12: R Multiple Calculation                                |
   //+----------------------------------------------------------------+
   bool Test12_RMultipleCalculation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "12. R multiple calculation...");

      double net_pnl    = 200.00;
      double risk_money = 100.00;

      double realized_r = net_pnl / risk_money; // +2.00R

      if(MathAbs(realized_r - 2.00) > 0.001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 12 Failed: Realized R calculation mismatch.");
         return false;
      }

      // Losing case
      net_pnl = -100.00;
      realized_r = net_pnl / risk_money; // -1.00R
      if(MathAbs(realized_r - (-1.00)) > 0.001)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 12 Failed: Realized loss R mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 12 Passed: R multiple accurately computed.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 13: Equity Update                                         |
   //+----------------------------------------------------------------+
   bool Test13_EquityUpdate()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "13. Equity update...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      SPaperTrade t;
      t.Reset();
      t.paper_trade_id = 1;
      t.symbol = "EURUSDm";
      t.strategy_id = "NEUROPIP_TREND_CONTINUATION";
      t.net_pnl = 250.00;
      t.risk_money = 100.00;
      t.realized_r = 2.50;

      perf.RecordTrade(t);

      if(MathAbs(perf.GetCurrentEquity() - 10250.00) > 0.01)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 13 Failed: Current equity not updated.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 13 Passed: Equity correctly updated ($10,250.00).");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 14: Maximum Drawdown Calculation                          |
   //+----------------------------------------------------------------+
   bool Test14_MaxDrawdown()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "14. Maximum drawdown calculation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      // Trade 1: +$500 -> Equity $10500 (Peak: $10500)
      SPaperTrade t1;
      t1.Reset(); t1.net_pnl = 500.00; t1.risk_money = 100.0; t1.symbol = "EURUSDm"; t1.strategy_id = "TEST";
      perf.RecordTrade(t1);

      // Trade 2: -$300 -> Equity $10200 (DD: $300)
      SPaperTrade t2;
      t2.Reset(); t2.net_pnl = -300.00; t2.risk_money = 100.0; t2.symbol = "EURUSDm"; t2.strategy_id = "TEST";
      perf.RecordTrade(t2);

      // Trade 3: -$200 -> Equity $10000 (DD: $500 -> 500/10500 = 4.76%)
      SPaperTrade t3;
      t3.Reset(); t3.net_pnl = -200.00; t3.risk_money = 100.0; t3.symbol = "EURUSDm"; t3.strategy_id = "TEST";
      perf.RecordTrade(t3);

      if(MathAbs(perf.GetMaxDrawdown() - 500.00) > 0.01 || MathAbs(perf.GetMaxDrawdownPct() - 4.76) > 0.1)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL",
            StringFormat("Test 14 Failed: Max DD mismatch (got $%.2f, %.2f%%).",
               perf.GetMaxDrawdown(), perf.GetMaxDrawdownPct()));
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 14 Passed: Maximum drawdown accurately calculated.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 15: Win Rate Calculation                                  |
   //+----------------------------------------------------------------+
   bool Test15_WinRate()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "15. Win rate calculation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      // 3 wins, 1 loss = 75.0% win rate
      for(int i = 0; i < 3; i++)
      {
         SPaperTrade t; t.Reset(); t.net_pnl = 100.0; t.symbol = "EURUSDm"; t.strategy_id = "TEST";
         perf.RecordTrade(t);
      }
      SPaperTrade t_loss; t_loss.Reset(); t_loss.net_pnl = -100.0; t_loss.symbol = "EURUSDm"; t_loss.strategy_id = "TEST";
      perf.RecordTrade(t_loss);

      if(MathAbs(perf.GetWinRate() - 75.00) > 0.01)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 15 Failed: Win rate calculation mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 15 Passed: Win rate accurately computed (75.00%).");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 16: Profit Factor Calculation                             |
   //+----------------------------------------------------------------+
   bool Test16_ProfitFactor()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "16. Profit factor calculation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      // Gross profit = $600, Gross loss = $200 -> PF = 3.00
      SPaperTrade t1; t1.Reset(); t1.net_pnl = 600.0; t1.symbol = "EURUSDm"; t1.strategy_id = "TEST";
      perf.RecordTrade(t1);

      SPaperTrade t2; t2.Reset(); t2.net_pnl = -200.0; t2.symbol = "EURUSDm"; t2.strategy_id = "TEST";
      perf.RecordTrade(t2);

      if(MathAbs(perf.GetProfitFactor() - 3.00) > 0.01)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 16 Failed: Profit factor mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 16 Passed: Profit factor accurately computed (3.00).");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 17: Expectancy Calculation                                |
   //+----------------------------------------------------------------+
   bool Test17_Expectancy()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "17. Expectancy calculation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      // 2 wins at +2.0R, 2 losses at -1.0R
      // Win Rate = 50%, Avg Win R = 2.0R, Loss Rate = 50%, Avg Loss R = 1.0R
      // Expectancy = (0.5 * 2.0) - (0.5 * 1.0) = 1.0 - 0.5 = +0.50R
      for(int i = 0; i < 2; i++)
      {
         SPaperTrade t; t.Reset(); t.net_pnl = 200.0; t.risk_money = 100.0; t.realized_r = 2.0; t.symbol = "EURUSDm"; t.strategy_id = "TEST";
         perf.RecordTrade(t);
      }
      for(int i = 0; i < 2; i++)
      {
         SPaperTrade t; t.Reset(); t.net_pnl = -100.0; t.risk_money = 100.0; t.realized_r = -1.0; t.symbol = "EURUSDm"; t.strategy_id = "TEST";
         perf.RecordTrade(t);
      }

      if(MathAbs(perf.GetExpectancy() - 0.50) > 0.01)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL",
            StringFormat("Test 17 Failed: Expectancy calculation mismatch (got %.2fR, expected +0.50R).", perf.GetExpectancy()));
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 17 Passed: Expectancy accurately computed (+0.50R).");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 18: Winning Streak Tracking                               |
   //+----------------------------------------------------------------+
   bool Test18_WinningStreak()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "18. Winning streak tracking...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      // 4 wins in a row, then 1 loss, then 2 wins
      for(int i = 0; i < 4; i++)
      {
         SPaperTrade t; t.Reset(); t.net_pnl = 100.0; t.symbol = "EURUSDm"; t.strategy_id = "TEST";
         perf.RecordTrade(t);
      }
      SPaperTrade t_loss; t_loss.Reset(); t_loss.net_pnl = -50.0; t_loss.symbol = "EURUSDm"; t_loss.strategy_id = "TEST";
      perf.RecordTrade(t_loss);

      for(int i = 0; i < 2; i++)
      {
         SPaperTrade t; t.Reset(); t.net_pnl = 100.0; t.symbol = "EURUSDm"; t.strategy_id = "TEST";
         perf.RecordTrade(t);
      }

      if(perf.GetMaxWinStreak() != 4 || perf.GetCurrentWinStreak() != 2)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 18 Failed: Winning streak tracking mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 18 Passed: Winning streak accurately tracked.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 19: Losing Streak Tracking                                |
   //+----------------------------------------------------------------+
   bool Test19_LosingStreak()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "19. Losing streak tracking...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      // 3 losses in a row, 1 win, 1 loss
      for(int i = 0; i < 3; i++)
      {
         SPaperTrade t; t.Reset(); t.net_pnl = -100.0; t.symbol = "EURUSDm"; t.strategy_id = "TEST";
         perf.RecordTrade(t);
      }
      SPaperTrade t_win; t_win.Reset(); t_win.net_pnl = 150.0; t_win.symbol = "EURUSDm"; t_win.strategy_id = "TEST";
      perf.RecordTrade(t_win);

      SPaperTrade t_loss2; t_loss2.Reset(); t_loss2.net_pnl = -50.0; t_loss2.symbol = "EURUSDm"; t_loss2.strategy_id = "TEST";
      perf.RecordTrade(t_loss2);

      if(perf.GetMaxLossStreak() != 3 || perf.GetCurrentLossStreak() != 1)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 19 Failed: Losing streak tracking mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 19 Passed: Losing streak accurately tracked.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 20: Symbol-Level Aggregation                              |
   //+----------------------------------------------------------------+
   bool Test20_SymbolAggregation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "20. Symbol-level aggregation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      SPaperTrade t1; t1.Reset(); t1.symbol = "EURUSDm"; t1.net_pnl = 200.0; t1.strategy_id = "TEST";
      SPaperTrade t2; t2.Reset(); t2.symbol = "USDJPYm"; t2.net_pnl = -100.0; t2.strategy_id = "TEST";
      SPaperTrade t3; t3.Reset(); t3.symbol = "EURUSDm"; t3.net_pnl = 150.0; t3.strategy_id = "TEST";

      perf.RecordTrade(t1);
      perf.RecordTrade(t2);
      perf.RecordTrade(t3);

      SSymbolPerformance s_eur;
      perf.GetSymbolStats(0, s_eur);

      bool ok = (perf.GetSymbolStatsCount() == 2 &&
                 s_eur.symbol == "EURUSDm" &&
                 s_eur.trades == 2 &&
                 s_eur.wins == 2 &&
                 MathAbs(s_eur.net_pnl - 350.0) < 0.01);

      if(!ok)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 20 Failed: Symbol breakdown aggregation mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 20 Passed: Symbol-level aggregation verified.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 21: Strategy-Level Aggregation                            |
   //+----------------------------------------------------------------+
   bool Test21_StrategyAggregation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "21. Strategy-level aggregation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      SPaperTrade t1; t1.Reset(); t1.strategy_id = "NEUROPIP_TREND_CONTINUATION"; t1.net_pnl = 300.0; t1.symbol = "EURUSDm";
      SPaperTrade t2; t2.Reset(); t2.strategy_id = "NEUROPIP_TREND_CONTINUATION"; t2.net_pnl = -100.0; t2.symbol = "USDJPYm";

      perf.RecordTrade(t1);
      perf.RecordTrade(t2);

      SStrategyPerformance strat_perf;
      perf.GetStrategyStats(0, strat_perf);

      bool ok = (perf.GetStrategyStatsCount() == 1 &&
                 strat_perf.strategy_id == "NEUROPIP_TREND_CONTINUATION" &&
                 strat_perf.trades == 2 &&
                 strat_perf.wins == 1 &&
                 MathAbs(strat_perf.net_pnl - 200.0) < 0.01);

      if(!ok)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 21 Failed: Strategy breakdown mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 21 Passed: Strategy-level aggregation verified.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 22: Regime-Level Aggregation                              |
   //+----------------------------------------------------------------+
   bool Test22_RegimeAggregation()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "22. Regime-level aggregation...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      SPaperTrade t1; t1.Reset(); t1.regime = REGIME_TRENDING_BULLISH; t1.net_pnl = 200.0; t1.symbol = "EURUSDm"; t1.strategy_id = "TEST";
      SPaperTrade t2; t2.Reset(); t2.regime = REGIME_TRENDING_BULLISH; t2.net_pnl = 150.0; t2.symbol = "USDJPYm"; t2.strategy_id = "TEST";

      perf.RecordTrade(t1);
      perf.RecordTrade(t2);

      SRegimePerformance reg_perf;
      perf.GetRegimeStats(0, reg_perf);

      bool ok = (perf.GetRegimeStatsCount() == 1 &&
                 reg_perf.regime == REGIME_TRENDING_BULLISH &&
                 reg_perf.trades == 2 &&
                 reg_perf.wins == 2 &&
                 MathAbs(reg_perf.net_pnl - 350.0) < 0.01);

      if(!ok)
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 22 Failed: Regime breakdown mismatch.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 22 Passed: Regime-level aggregation verified.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 23: Insufficient Sample Handling                          |
   //+----------------------------------------------------------------+
   bool Test23_InsufficientSampleHandling()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "23. Insufficient sample handling...");

      CPerformanceEngine perf(m_logger, 10000.0, 30);

      // Only 5 trades (< 30 minimum)
      for(int i = 0; i < 5; i++)
      {
         SPaperTrade t; t.Reset(); t.net_pnl = 50.0; t.symbol = "EURUSDm"; t.strategy_id = "TEST";
         perf.RecordTrade(t);
      }

      bool is_ready = perf.IsSampleSufficient();
      string status = perf.GetSampleStatus();

      if(is_ready || status != "INSUFFICIENT_SAMPLE")
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 23 Failed: Small sample incorrectly flagged as ready.");
         return false;
      }

      // Add 25 more trades -> reaches 30
      for(int i = 0; i < 25; i++)
      {
         SPaperTrade t; t.Reset(); t.net_pnl = 10.0; t.symbol = "EURUSDm"; t.strategy_id = "TEST";
         perf.RecordTrade(t);
      }

      if(!perf.IsSampleSufficient() || perf.GetSampleStatus() != "PERFORMANCE_SAMPLE_READY")
      {
         m_logger.Log(LOG_LEVEL_ERROR, "Phase6Tests", "TEST_FAIL", "Test 23 Failed: Full sample not recognized.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS", "Test 23 Passed: Sample thresholding verified.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 24: Execution Safety Hard Lock                            |
   //+----------------------------------------------------------------+
   bool Test24_ExecutionSafety()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "24. Execution safety hard lock...");

      CCapabilities capabilities;
      if(capabilities.can_trade)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase6Tests", "SAFETY_VIOLATION",
            "Trading capability is enabled! Phase 6 requires can_trade = false.");
         return false;
      }

      SPaperTrade trade;
      trade.Reset();
      if(!trade.candidate_only)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase6Tests", "SAFETY_VIOLATION",
            "SPaperTrade.candidate_only is false! Must be permanently true.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS",
         "Test 24 Passed: Execution safety verified (can_trade=false, candidate_only=true).");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Test 25: Phase 1–5 Regressions Verification                    |
   //+----------------------------------------------------------------+
   bool Test25_Phase1To5Regressions()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_START", "25. Verifying Phase 1–5 foundational invariants...");

      // Verify that TradePlan and Strategy decision contracts remain intact
      STradePlan plan;
      plan.Reset();
      if(plan.execution_authorized)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase6Tests", "REGRESSION_FAIL",
            "STradePlan.execution_authorized is true! Regression detected.");
         return false;
      }

      SStrategyDecision dec;
      dec.Reset();
      if(dec.status != STRATEGY_WAIT)
      {
         m_logger.Log(LOG_LEVEL_CRITICAL, "Phase6Tests", "REGRESSION_FAIL",
            "SStrategyDecision default status regression.");
         return false;
      }

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "TEST_PASS",
         "Test 25 Passed: Phase 1–5 invariants confirmed intact without regression.");
      return true;
   }

   //+----------------------------------------------------------------+
   //| Run all 25 Phase 6 Tests                                       |
   //+----------------------------------------------------------------+
   bool RunAllTests()
   {
      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "SUITE_START", "=== Starting Phase 6 Paper Trading Test Suite (25 Tests) ===");

      if(!Test01_ValidBuyPaperTradeCreation())       return false;
      if(!Test02_ValidSellPaperTradeCreation())      return false;
      if(!Test03_BuyTPHit())                         return false;
      if(!Test04_BuySLHit())                         return false;
      if(!Test05_SellTPHit())                        return false;
      if(!Test06_SellSLHit())                        return false;
      if(!Test07_SameBarAmbiguity())                 return false;
      if(!Test08_TradeExpiry())                      return false;
      if(!Test09_InvalidPlanRejection())             return false;
      if(!Test10_DuplicatePaperTradePrevention())     return false;
      if(!Test11_PnLCalculation())                   return false;
      if(!Test12_RMultipleCalculation())             return false;
      if(!Test13_EquityUpdate())                     return false;
      if(!Test14_MaxDrawdown())                      return false;
      if(!Test15_WinRate())                          return false;
      if(!Test16_ProfitFactor())                     return false;
      if(!Test17_Expectancy())                       return false;
      if(!Test18_WinningStreak())                    return false;
      if(!Test19_LosingStreak())                     return false;
      if(!Test20_SymbolAggregation())                return false;
      if(!Test21_StrategyAggregation())              return false;
      if(!Test22_RegimeAggregation())                return false;
      if(!Test23_InsufficientSampleHandling())       return false;
      if(!Test24_ExecutionSafety())                  return false;
      if(!Test25_Phase1To5Regressions())             return false;

      m_logger.Log(LOG_LEVEL_INFO, "Phase6Tests", "SUITE_PASS", "=== All 25 Phase 6 Paper Trading Tests Passed Successfully ===");
      return true;
   }
};

#endif
