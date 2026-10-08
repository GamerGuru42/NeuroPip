//+------------------------------------------------------------------+
//| Phase8Tests.mqh                                                  |
//| ATG Trading Engine - Phase 8                                     |
//| Extended Paper Validation & Statistical Evaluation Test Suite    |
//| MONITOR_ONLY - No execution capability                           |
//|                                                                  |
//| Covers 30 comprehensive Phase 8 verification test cases:         |
//|  1. Dataset empty validation                                     |
//|  2. Dataset valid validation                                     |
//|  3. Dataset anomalies and corruption detection                   |
//|  4. Distribution metrics (mean, std dev)                         |
//|  5. Distribution percentiles (P10, P25, P50, P75, P90)           |
//|  6. Sample size classification (<15, 15-29, >=30)                |
//|  7. Core performance (Win Rate, Gross Profit/Loss, PF)           |
//|  8. Expectancy & Realized R calculation                          |
//|  9. Drawdown & Streak tracking                                   |
//| 10. Per-symbol evaluation                                        |
//| 11. Per-regime evaluation                                        |
//| 12. Directional evaluation (BUY vs SELL)                         |
//| 13. Equity curve & volatility analysis                           |
//| 14. Risk contract clean audit (zero violations)                  |
//| 15. Risk contract violations detection                           |
//| 16. Trade quality & confidence correlation                       |
//| 17. Out-of-sample partitioning insufficient (<20 trades)         |
//| 18. Out-of-sample partitioning valid (50/25/25 split)            |
//| 19. Walk-forward analysis insufficient (<40 trades)              |
//| 20. Walk-forward multi-window valid analysis                     |
//| 21. Monte Carlo bootstrap resampling                             |
//| 22. Robustness slippage & spread stress checks                   |
//| 23. Evidence classification - insufficient sample                |
//| 24. Evidence classification - robust paper evidence              |
//| 25. Master full evaluation pipeline execution                    |
//| 26. Comprehensive evaluation report generation                   |
//| 27. Hard safety gate (can_trade == false, ExecutionGuard locked)|
//| 28. Phase 3 regression verification                              |
//| 29. Phase 4 & Phase 5 regression verification                    |
//| 30. Phase 6 & Phase 7 regression verification                    |
//+------------------------------------------------------------------+
#ifndef ATG_PHASE8_TESTS_MQH
#define ATG_PHASE8_TESTS_MQH

#include "../Diagnostics/Logger.mqh"
#include "../Security/Capabilities.mqh"
#include "../Execution/ExecutionGuard.mqh"
#include "../Core/RuntimeState.mqh"
#include "../Analytics/EvaluationTypes.mqh"
#include "../Analytics/StatisticalEvaluationEngine.mqh"
#include "Phase3Tests.mqh"
#include "Phase4Tests.mqh"
#include "Phase5Tests.mqh"
#include "Phase6Tests.mqh"
#include "Phase7Tests.mqh"

class CPhase8Tests
{
private:
   CLogger* m_logger;

   void SetupMockTrade(SPaperTrade &t, ulong id, const string symbol, ENUM_ATG_TRADE_DIRECTION dir,
                       double entry, double sl, double tp, double vol, double pnl, ENUM_PAPER_TRADE_STATUS status,
                       datetime entry_time = 1700000000, datetime exit_time = 1700001000,
                       double confidence = 0.85, double quality = 0.80,
                       ENUM_ATG_MARKET_REGIME reg = REGIME_TRENDING_BULLISH,
                       string exit_reason = EXIT_REASON_TP)
   {
      t.Reset();
      t.paper_trade_id       = id;
      t.source_plan_id       = id + 1000;
      t.strategy_id          = "ATG_TREND_CONTINUATION";
      t.symbol               = symbol;
      t.direction            = dir;
      t.primary_timeframe    = PERIOD_M15;
      t.entry_time           = entry_time;
      t.exit_time            = exit_time;
      t.source_bar_time      = entry_time - 900;
      t.holding_duration_sec = (int)(exit_time - entry_time);
      t.entry_price          = entry;
      t.stop_loss            = sl;
      t.take_profit          = tp;
      t.exit_price           = (pnl >= 0.0) ? tp : sl;
      t.volume               = vol;
      t.risk_money           = 10.0;
      t.equity_at_entry      = 1000.0;
      t.risk_percent         = 1.0;
      t.planned_rr           = 2.0;
      t.gross_pnl            = pnl;
      t.simulated_costs      = 0.0;
      t.net_pnl              = pnl;
      t.realized_r           = pnl / 10.0;
      t.status               = status;
      t.exit_reason          = (pnl >= 0.0) ? exit_reason : EXIT_REASON_SL;
      t.strategy_confidence  = confidence;
      t.strategy_quality     = quality;
      t.regime               = reg;
      t.explanation          = "Phase 8 synthetic evaluation setup";
      t.candidate_only       = true;
   }

public:
   CPhase8Tests(CLogger* logger = NULL) : m_logger(logger) {}

   // 1. Dataset empty validation
   bool Test01_DatasetEmptyValidation()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      SDatasetValidationReport report;
      engine.ValidateDataset(trades, report);
      return (report.status == DATASET_STATUS_EMPTY && report.total_records == 0);
   }

   // 2. Dataset valid validation
   bool Test02_DatasetValidValidation()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 20);
      for(int i = 0; i < 20; i++)
      {
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY,
                        1.0800, 1.0750, 1.0900, 0.02, (i % 2 == 0 ? 20.0 : -10.0),
                        PAPER_CLOSED_TP, 1700000000 + (i * 1000), 1700000500 + (i * 1000));
      }
      SDatasetValidationReport report;
      engine.ValidateDataset(trades, report);
      return (report.status == DATASET_STATUS_VALID && report.valid_records == 20 && report.rejected_records == 0);
   }

   // 3. Dataset anomalies and corruption detection
   bool Test03_DatasetAnomaliesAndCorrupt()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 5);
      // Valid trade
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0750, 1.0900, 0.02, 20.0, PAPER_CLOSED_TP, 1700000000, 1700001000);
      // Duplicate ID
      SetupMockTrade(trades[1], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0750, 1.0900, 0.02, 20.0, PAPER_CLOSED_TP, 1700000000, 1700001000);
      // Invalid price (0 entry)
      SetupMockTrade(trades[2], 2, "EURUSDm", ATG_DIRECTION_BUY, 0.0, 1.0750, 1.0900, 0.02, -10.0, PAPER_CLOSED_TP, 1700000000, 1700001000);
      // Temporal inversion (exit before entry)
      SetupMockTrade(trades[3], 3, "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0750, 1.0900, 0.02, -10.0, PAPER_CLOSED_TP, 1700001000, 1700000500);
      // Valid trade
      SetupMockTrade(trades[4], 4, "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0750, 1.0900, 0.02, 20.0, PAPER_CLOSED_TP, 1700002000, 1700003000);

      SDatasetValidationReport report;
      engine.ValidateDataset(trades, report);
      return (report.status == DATASET_STATUS_PARTIAL_ANOMALIES || report.status == DATASET_STATUS_INSUFFICIENT) &&
             (report.rejected_records == 3 && report.valid_records == 2);
   }

   // 4. Distribution metrics (mean, std dev)
   bool Test04_DistributionMetricsMeanSD()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      double vals[] = { 10.0, 20.0, 30.0, 40.0, 50.0 };
      SDistributionMetrics dist;
      engine.CalculateDistribution(vals, dist);
      // Mean should be 30.0, std dev should be sqrt((400+100+0+100+400)/4) = sqrt(250) approx 15.811
      return (MathAbs(dist.mean - 30.0) < 0.001 && MathAbs(dist.std_dev - 15.811) < 0.01);
   }

   // 5. Distribution percentiles (P10, P25, P50, P75, P90)
   bool Test05_DistributionPercentiles()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      double vals[];
      ArrayResize(vals, 101);
      for(int i = 0; i <= 100; i++) vals[i] = (double)i;
      SDistributionMetrics dist;
      engine.CalculateDistribution(vals, dist);
      return (MathAbs(dist.median - 50.0) < 0.01 &&
              MathAbs(dist.p10 - 10.0) < 0.01 &&
              MathAbs(dist.p25 - 25.0) < 0.01 &&
              MathAbs(dist.p75 - 75.0) < 0.01 &&
              MathAbs(dist.p90 - 90.0) < 0.01);
   }

   // 6. Sample size classification (<15, 15-29, >=30)
   bool Test06_SampleSizeClassification()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade t10[], t20[], t35[];
      ArrayResize(t10, 10);
      ArrayResize(t20, 20);
      ArrayResize(t35, 35);
      for(int i = 0; i < 35; i++)
      {
         SPaperTrade tr;
         SetupMockTrade(tr, (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 10.0, PAPER_CLOSED_TP);
         if(i < 10) t10[i] = tr;
         if(i < 20) t20[i] = tr;
         t35[i] = tr;
      }
      SPhase8EvaluationResult r10, r20, r35;
      r10.Reset();
      r20.Reset();
      r35.Reset();
      engine.EvaluateOverallPerformance(t10, r10);
      engine.EvaluateOverallPerformance(t20, r20);
      engine.EvaluateOverallPerformance(t35, r35);
      return (r10.sample_tier == SAMPLE_INSUFFICIENT &&
              r20.sample_tier == SAMPLE_PRELIMINARY &&
              r35.sample_tier == SAMPLE_ADEQUATE_FOR_EVALUATION);
   }

   // 7. Core performance (Win Rate, Gross Profit/Loss, PF)
   bool Test07_CorePerformanceWinLossPF()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 4);
      // 3 wins of $20, 1 loss of $10 -> WinRate = 75%, Gross Profit = $60, Gross Loss = $10, PF = 6.0
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[2], 3, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[3], 4, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP);

      SPhase8EvaluationResult res;
      res.Reset();
      engine.EvaluateOverallPerformance(trades, res);
      return (res.total_trades == 4 && res.winning_trades == 3 && res.losing_trades == 1 &&
              MathAbs(res.win_rate - 75.0) < 0.01 &&
              MathAbs(res.gross_profit - 60.0) < 0.01 &&
              MathAbs(res.gross_loss - 10.0) < 0.01 &&
              MathAbs(res.profit_factor - 6.0) < 0.01 &&
              MathAbs(res.net_pnl - 50.0) < 0.01);
   }

   // 8. Expectancy & Realized R calculation
   bool Test08_ExpectancyCalculation()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 2);
      // Trade 1: +2.0R ($20), Trade 2: -1.0R (-$10). Expectancy = (0.5 * 2.0) - (0.5 * 1.0) = 0.5R
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP);

      SPhase8EvaluationResult res;
      res.Reset();
      engine.EvaluateOverallPerformance(trades, res);
      return (MathAbs(res.expectancy - 0.500) < 0.001 && MathAbs(res.avg_r - 0.500) < 0.001);
   }

   // 9. Drawdown & Streak tracking
   bool Test09_DrawdownAndStreaks()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 5);
      // Win (+20), Win (+20) -> Eq 1040 (peak)
      // Loss (-10), Loss (-10), Loss (-10) -> Eq 1010. Max DD = $30. Max win streak = 2, max loss streak = 3.
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[2], 3, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[3], 4, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[4], 5, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP);

      SPhase8EvaluationResult res;
      res.Reset();
      engine.EvaluateOverallPerformance(trades, res);
      return (MathAbs(res.max_drawdown - 30.0) < 0.01 &&
              res.max_win_streak == 2 &&
              res.max_loss_streak == 3);
   }

   // 10. Per-symbol evaluation
   bool Test10_SymbolEvaluation()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 3);
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[2], 3, "USDJPYm", ATG_DIRECTION_BUY, 150.0, 149.5, 151.0, 0.02, 20.0, PAPER_CLOSED_TP);

      SSymbolEvaluation evals[];
      engine.EvaluateSymbols(trades, evals);
      return (ArraySize(evals) == 2 &&
              ((evals[0].symbol == "EURUSDm" && evals[0].sample_size == 2) || (evals[1].symbol == "EURUSDm" && evals[1].sample_size == 2)));
   }

   // 11. Per-regime evaluation
   bool Test11_RegimeEvaluation()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 2);
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP, 1700000000, 1700001000, 0.8, 0.8, REGIME_TRENDING_BULLISH);
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_SELL, 1.08, 1.085, 1.07, 0.02, 20.0, PAPER_CLOSED_TP, 1700000000, 1700001000, 0.8, 0.8, REGIME_TRENDING_BEARISH);

      SRegimeEvaluation evals[];
      engine.EvaluateRegimes(trades, evals);
      return (ArraySize(evals) == 2);
   }

   // 12. Directional evaluation (BUY vs SELL)
   bool Test12_DirectionEvaluation()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 2);
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_SELL, 1.08, 1.085, 1.07, 0.02, -10.0, PAPER_CLOSED_TP);

      SDirectionEvaluation evals[];
      ArrayResize(evals, 2);
      engine.EvaluateDirections(trades, evals);
      return (evals[0].trades == 1 && evals[0].wins == 1 &&
              evals[1].trades == 1 && evals[1].losses == 1);
   }

   // 13. Equity curve & volatility analysis
   bool Test13_EquityCurveVolatility()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 3);
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 30.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP);
      SetupMockTrade(trades[2], 3, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);

      SEquityCurveAnalysis eq;
      engine.EvaluateEquityCurve(trades, 1000.0, eq);
      return (MathAbs(eq.final_equity - 1040.0) < 0.01 &&
              MathAbs(eq.peak_equity - 1040.0) < 0.01 &&
              MathAbs(eq.max_drawdown - 10.0) < 0.01 &&
              eq.equity_volatility > 0.0);
   }

   // 14. Risk contract clean audit (zero violations)
   bool Test14_RiskContractClean()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 10);
      for(int i = 0; i < 10; i++)
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);

      SRiskValidationReport report;
      engine.ValidateRiskContract(trades, report);
      return (report.total_audited == 10 && report.violations_count == 0 && report.valid_risk_percent_count == 10);
   }

   // 15. Risk contract violations detection
   bool Test15_RiskContractViolations()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 2);
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      // Inject violation: risk_percent = 5.0% (> 2.0% limit)
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);
      trades[1].risk_percent = 5.0;

      SRiskValidationReport report;
      engine.ValidateRiskContract(trades, report);
      return (report.violations_count > 0);
   }

   // 16. Trade quality & confidence correlation
   bool Test16_TradeQualityCorrelation()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 4);
      // High confidence (0.85) -> 2 wins
      SetupMockTrade(trades[0], 1, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP, 1700000000, 1700001000, 0.85);
      SetupMockTrade(trades[1], 2, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP, 1700000000, 1700001000, 0.85);
      // Low confidence (0.50) -> 2 losses
      SetupMockTrade(trades[2], 3, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP, 1700000000, 1700001000, 0.50);
      SetupMockTrade(trades[3], 4, "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, -10.0, PAPER_CLOSED_TP, 1700000000, 1700001000, 0.50);

      STradeQualityAnalysis qual;
      engine.AnalyzeTradeQuality(trades, qual);
      return (qual.high_confidence_trades == 2 && MathAbs(qual.high_confidence_win_rate - 100.0) < 0.01 &&
              qual.low_confidence_trades == 2 && MathAbs(qual.low_confidence_win_rate - 0.0) < 0.01);
   }

   // 17. Out-of-sample partitioning insufficient (<20 trades)
   bool Test17_OutOfSamplePartitioningInsufficient()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 15);
      for(int i = 0; i < 15; i++)
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);

      SOutOfSampleResult oos;
      engine.EvaluateOutOfSample(trades, oos);
      return (StringFind(oos.status, "INSUFFICIENT_DATA") >= 0);
   }

   // 18. Out-of-sample partitioning valid (50/25/25 split)
   bool Test18_OutOfSamplePartitioningValid()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 40);
      for(int i = 0; i < 40; i++)
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, (i % 2 == 0 ? 20.0 : -10.0), PAPER_CLOSED_TP);

      SOutOfSampleResult oos;
      engine.EvaluateOutOfSample(trades, oos);
      return (oos.status == "SPLIT_VALID" && oos.train_count == 20 && oos.val_count == 10 && oos.oos_count == 10);
   }

   // 19. Walk-forward analysis insufficient (<40 trades)
   bool Test19_WalkForwardInsufficient()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 30);
      for(int i = 0; i < 30; i++)
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 20.0, PAPER_CLOSED_TP);

      SWalkForwardResult wf;
      engine.EvaluateWalkForward(trades, wf);
      return (wf.status == "INSUFFICIENT_DATA");
   }

   // 20. Walk-forward multi-window valid analysis
   bool Test20_WalkForwardValid()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 44);
      for(int i = 0; i < 44; i++)
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 10.0, PAPER_CLOSED_TP);

      SWalkForwardResult wf;
      engine.EvaluateWalkForward(trades, wf);
      return (wf.status == "WALK_FORWARD_VALID" && wf.windows_tested == 4);
   }

   // 21. Monte Carlo bootstrap resampling
   bool Test21_MonteCarloResampling()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 20);
      for(int i = 0; i < 20; i++)
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, (i % 2 == 0 ? 20.0 : -10.0), PAPER_CLOSED_TP);

      SMonteCarloResult mc;
      engine.RunMonteCarloResampling(trades, 100, mc);
      return (mc.status == "SIMULATED_BOOTSTRAP" && mc.simulations_count == 100 && mc.p95_drawdown >= 0.0);
   }

   // 22. Robustness slippage & spread stress checks
   bool Test22_RobustnessSlippageSpreadStress()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 20);
      // All trades +1.0R (net pnl 10.0)
      for(int i = 0; i < 20; i++)
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 10.0, PAPER_CLOSED_TP);

      SRobustnessResult rob;
      engine.RunRobustnessChecks(trades, rob);
      // Baseline 1.0R, adverse slippage 0.95R, wide spread 0.90R -> ROBUST_SURVIVAL
      return (MathAbs(rob.baseline_expectancy - 1.000) < 0.01 &&
              MathAbs(rob.adverse_slippage_expectancy - 0.950) < 0.01 &&
              rob.edge_survival_status == "ROBUST_SURVIVAL");
   }

   // 23. Evidence classification - insufficient sample
   bool Test23_EvidenceClassificationInsufficient()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPhase8EvaluationResult res;
      res.Reset();
      res.total_trades = 10;
      res.dataset_report.valid_records = 10;
      res.sample_tier = SAMPLE_INSUFFICIENT;

      ENUM_EVIDENCE_CLASSIFICATION verdict = engine.ClassifyEvidence(res);
      return (verdict == EVIDENCE_INSUFFICIENT_SAMPLE);
   }

   // 24. Evidence classification - robust paper evidence
   bool Test24_EvidenceClassificationRobust()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPhase8EvaluationResult res;
      res.Reset();
      res.total_trades = 50;
      res.dataset_report.status = DATASET_STATUS_VALID;
      res.dataset_report.valid_records = 50;
      res.sample_tier = SAMPLE_ADEQUATE_FOR_EVALUATION;
      res.expectancy = 0.45;
      res.profit_factor = 2.10;
      res.oos_result.oos_expectancy = 0.35;
      res.robustness_result.adverse_slippage_expectancy = 0.30;
      res.monte_carlo_result.p95_drawdown = 8.5;

      ENUM_EVIDENCE_CLASSIFICATION verdict = engine.ClassifyEvidence(res);
      return (verdict == EVIDENCE_ROBUST_PAPER_EVIDENCE);
   }

   // 25. Master full evaluation pipeline execution
   bool Test25_FullEvaluationPipeline()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 35);
      for(int i = 0; i < 35; i++)
      {
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY,
                        1.0800, 1.0750, 1.0900, 0.02, (i % 3 == 0 ? -10.0 : 20.0),
                        PAPER_CLOSED_TP, 1700000000 + (i * 1000), 1700000500 + (i * 1000));
      }

      SPhase8EvaluationResult result;
      bool ok = engine.RunFullEvaluation(trades, result, 1000.0, 100);
      return (ok && result.total_trades == 35 && result.dataset_report.valid_records == 35 &&
              result.evidence_class != EVIDENCE_INSUFFICIENT_SAMPLE);
   }

   // 26. Comprehensive evaluation report generation
   bool Test26_ReportFormatting()
   {
      CStatisticalEvaluationEngine engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 20);
      for(int i = 0; i < 20; i++)
         SetupMockTrade(trades[i], (ulong)(i + 1), "EURUSDm", ATG_DIRECTION_BUY, 1.08, 1.075, 1.09, 0.02, 10.0, PAPER_CLOSED_TP);

      SPhase8EvaluationResult result;
      engine.RunFullEvaluation(trades, result, 1000.0, 50);
      string rep = engine.GenerateFullEvaluationReport(result);
      return (StringLen(rep) > 200 &&
              StringFind(rep, "PHASE 8 STATISTICAL EVALUATION REPORT") >= 0 &&
              StringFind(rep, "OVERALL CORE PERFORMANCE") >= 0);
   }

   // 27. Hard safety gate (can_trade == false, ExecutionGuard locked)
   bool Test27_HardSafetyGate()
   {
      CCapabilities caps;
      CRuntimeState state;
      state.mode = MODE_MONITOR_ONLY;
      CExecutionGuard guard(m_logger, &caps, &state);

      SATGTradeIntent intent;
      ZeroMemory(intent);
      intent.request_id = 999901;
      intent.symbol = "EURUSDm";
      intent.direction = ATG_DIRECTION_BUY;
      intent.volume = 0.01;

      bool allowed = guard.Validate(intent);
      return (!allowed && intent.rejection_reason == ATG_REJECT_EXECUTION_DISABLED && !caps.can_trade);
   }

   // 28. Phase 3 regression verification
   bool Test28_RegressionPhases1To3()
   {
      CPhase3Tests p3(m_logger);
      return p3.RunAllTests();
   }

   // 29. Phase 4 & Phase 5 regression verification
   bool Test29_RegressionPhases4To5()
   {
      CPhase4Tests p4(m_logger);
      if(!p4.RunAllTests()) return false;
      CPhase5Tests p5(m_logger);
      return p5.RunAllTests();
   }

   // 30. Phase 6 & Phase 7 regression verification
   bool Test30_RegressionPhases6To7()
   {
      CPhase6Tests p6(m_logger);
      if(!p6.RunAllTests()) return false;
      CPhase7Tests p7(m_logger);
      return p7.RunAllTests();
   }

   // Master Test Runner
   bool RunAllTests()
   {
      if(m_logger != NULL)
         m_logger.Log(LOG_LEVEL_INFO, "Phase8Tests", "TEST_SUITE_START", "Starting Phase 8 Extended Paper Validation & Statistical Evaluation Tests (30 cases)...");

      int passed = 0;
      int total  = 30;

      if(Test01_DatasetEmptyValidation()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test01 failed");
      if(Test02_DatasetValidValidation()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test02 failed");
      if(Test03_DatasetAnomaliesAndCorrupt()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test03 failed");
      if(Test04_DistributionMetricsMeanSD()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test04 failed");
      if(Test05_DistributionPercentiles()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test05 failed");
      if(Test06_SampleSizeClassification()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test06 failed");
      if(Test07_CorePerformanceWinLossPF()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test07 failed");
      if(Test08_ExpectancyCalculation()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test08 failed");
      if(Test09_DrawdownAndStreaks()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test09 failed");
      if(Test10_SymbolEvaluation()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test10 failed");
      if(Test11_RegimeEvaluation()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test11 failed");
      if(Test12_DirectionEvaluation()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test12 failed");
      if(Test13_EquityCurveVolatility()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test13 failed");
      if(Test14_RiskContractClean()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test14 failed");
      if(Test15_RiskContractViolations()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test15 failed");
      if(Test16_TradeQualityCorrelation()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test16 failed");
      if(Test17_OutOfSamplePartitioningInsufficient()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test17 failed");
      if(Test18_OutOfSamplePartitioningValid()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test18 failed");
      if(Test19_WalkForwardInsufficient()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test19 failed");
      if(Test20_WalkForwardValid()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test20 failed");
      if(Test21_MonteCarloResampling()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test21 failed");
      if(Test22_RobustnessSlippageSpreadStress()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test22 failed");
      if(Test23_EvidenceClassificationInsufficient()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test23 failed");
      if(Test24_EvidenceClassificationRobust()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test24 failed");
      if(Test25_FullEvaluationPipeline()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test25 failed");
      if(Test26_ReportFormatting()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test26 failed");
      if(Test27_HardSafetyGate()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test27 failed");
      if(Test28_RegressionPhases1To3()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test28 failed");
      if(Test29_RegressionPhases4To5()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test29 failed");
      if(Test30_RegressionPhases6To7()) passed++; else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase8Tests", "FAIL", "Test30 failed");

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "Phase8Tests", "TEST_SUITE_END",
            StringFormat("Phase 8 Test Suite Complete: %d / %d tests passed.", passed, total));
      }

      return (passed == total);
   }
};

#endif
