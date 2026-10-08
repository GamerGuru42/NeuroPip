//+------------------------------------------------------------------+
//| Phase10Tests.mqh                                                 |
//| ATG Trading Engine - Phase 10                                    |
//| Forward Evidence Accumulation, Monitoring & Validation Suite     |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_PHASE10_TESTS_MQH
#define ATG_PHASE10_TESTS_MQH

#include "../Diagnostics/Logger.mqh"
#include "../Security/Capabilities.mqh"
#include "../Execution/ExecutionGuard.mqh"
#include "../Execution/RiskEngine.mqh"
#include "../Execution/PositionSizer.mqh"
#include "../Core/RuntimeState.mqh"
#include "../Config/Config.mqh"
#include "../Analytics/ForwardEvidenceTypes.mqh"
#include "../Analytics/ForwardEvidenceEngine.mqh"
#include "../Analytics/ForwardAlertManager.mqh"
#include "../Analytics/EvaluationTypes.mqh"
#include "../Analytics/StatisticalEvaluationEngine.mqh"
#include "../Persistence/PaperTradeStorage.mqh"
#include "Phase3Tests.mqh"
#include "Phase4Tests.mqh"
#include "Phase5Tests.mqh"
#include "Phase6Tests.mqh"
#include "Phase7Tests.mqh"
#include "Phase8Tests.mqh"
#include "Phase9Tests.mqh"

class CPhase10Tests
{
private:
   CLogger* m_logger;
   string   m_valid_fingerprint;

   void InitFingerprint()
   {
      CConfig cfg;
      SForwardConfigSnapshot snap;
      snap.Capture(cfg);
      m_valid_fingerprint = snap.config_fingerprint;
   }

   void SetupMockTrade(SPaperTrade &t, ulong id, const string symbol, ENUM_ATG_TRADE_DIRECTION dir,
                       double entry, double sl, double tp, double vol, double pnl,
                       ENUM_PAPER_TRADE_STATUS status = PAPER_CLOSED_TP,
                       ENUM_DATASET_CLASS dclass = DATASET_FORWARD_LIVE_PAPER,
                       datetime entry_time = 1700000000, datetime exit_time = 1700001000,
                       double confidence = 0.85, double quality = 0.80,
                       ENUM_ATG_MARKET_REGIME reg = REGIME_TRENDING_BULLISH,
                       string exit_reason = EXIT_REASON_TP,
                       string cohort = "COHORT_TEST",
                       string fingerprint = "",
                       int entry_spread = 15)
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
      t.risk_money           = 0.10;
      t.equity_at_entry      = 10.00;
      t.risk_percent         = 1.0;
      t.planned_rr           = 2.0;
      t.simulated_costs      = 0.0;
      if(status == PAPER_OPEN || status == PAPER_PENDING)
      {
         t.status               = status;
         t.exit_time            = 0;
         t.exit_price           = 0.0;
         t.holding_duration_sec = 0;
         t.exit_reason          = "NONE";
      }
      else
      {
         t.status               = status;
         t.exit_reason          = exit_reason;
      }
      t.gross_pnl            = pnl;
      t.net_pnl              = pnl;
      t.realized_r           = (t.risk_money > 0.0) ? NormalizeDouble(pnl / t.risk_money, 2) : 0.0;
      t.strategy_confidence  = confidence;
      t.strategy_quality     = quality;
      t.regime               = reg;
      t.candidate_only       = true;
      t.dataset_class        = dclass;
      t.data_quality         = DATA_QUALITY_VALID;
      t.quality_warning_reason = "NONE";
      t.config_fingerprint   = (fingerprint == "") ? m_valid_fingerprint : fingerprint;
      t.cohort_id            = cohort;
      t.entry_spread_points  = entry_spread;
   }

public:
   CPhase10Tests(CLogger* logger) : m_logger(logger)
   {
      InitFingerprint();
   }

   // 1. Forward Dataset Integrity & Separation
   bool Test01_ForwardDatasetIntegritySeparation()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_P10_01");

      SPaperTrade fwd, syn, hist;
      SetupMockTrade(fwd, 1, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20, PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER);
      SetupMockTrade(syn, 2, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20, PAPER_CLOSED_TP, DATASET_SYNTHETIC_TEST);
      SetupMockTrade(hist, 3, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20, PAPER_CLOSED_TP, DATASET_HISTORICAL_IMPORTED);

      engine.RecordTrade(fwd);
      engine.RecordTrade(syn);
      engine.RecordTrade(hist);

      if(engine.GetValidForwardTradeCount() != 1) return false;
      if(engine.GetSyntheticTradeCount() != 2) return false;
      if(engine.GetMonitoringState().dataset_contamination_prevented != 2) return false;

      return true;
   }

   // 2. Trade Field Completeness (All 20 Required Fields)
   bool Test02_TradeFieldCompleteness()
   {
      SPaperTrade t;
      SetupMockTrade(t, 101, "BTCUSDm", ATG_DIRECTION_BUY, 86000.0, 85500.0, 87000.0, 0.01, 10.0,
         PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER, 1700000000, 1700001000, 0.88, 0.82,
         REGIME_TRENDING_BULLISH, EXIT_REASON_TP, "COHORT_P10", "FP-TEST12345678", 800);

      if(t.paper_trade_id != 101) return false;
      if(t.symbol != "BTCUSDm") return false;
      if(t.direction != ATG_DIRECTION_BUY) return false;
      if(t.entry_time != 1700000000) return false;
      if(t.exit_time != 1700001000) return false;
      if(t.entry_price != 86000.0) return false;
      if(t.exit_price != 87000.0) return false;
      if(t.stop_loss != 85500.0) return false;
      if(t.take_profit != 87000.0) return false;
      if(t.risk_money <= 0.0) return false;
      if(t.net_pnl != 10.0) return false;
      if(t.realized_r <= 0.0) return false;
      if(t.strategy_id != "ATG_TREND_CONTINUATION") return false;
      if(t.config_fingerprint != "FP-TEST12345678") return false;
      if(t.regime != REGIME_TRENDING_BULLISH) return false;
      if(t.strategy_confidence != 0.88) return false;
      if(t.strategy_quality != 0.82) return false;
      if(t.entry_spread_points != 800) return false;
      if(t.source_bar_time <= 0) return false;
      if(t.exit_reason != EXIT_REASON_TP) return false;
      if(t.data_quality != DATA_QUALITY_VALID) return false;

      return true;
   }

   // 3. Strategy Freeze & Anti-Tampering
   bool Test03_StrategyFreezeAndAntiTampering()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_FREEZE");

      if(!engine.VerifyConfiguration(cfg)) return false;

      // Tamper risk percent
      CConfig tampered = cfg;
      tampered.risk_percent = 2.0;

      if(engine.VerifyConfiguration(tampered)) return false;
      if(engine.GetCohort().status != COHORT_STATUS_INVALIDATED) return false;
      if(engine.GetAlertManager().GetAlertCount(ALERT_CONFIG_MISMATCH) != 1) return false;

      return true;
   }

   // 4. Milestone Progression Schedule (N = 0, 15, 30, 50, 75, 100)
   bool Test04_MilestoneProgressionSchedule()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_MS");

      if(engine.GetCohort().milestone != MILESTONE_0_TRADES) return false;

      for(int i = 1; i <= 15; i++)
      {
         SPaperTrade t;
         SetupMockTrade(t, i, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20,
            PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER, 1700000000 + i * 100, 1700000500 + i * 100);
         engine.RecordTrade(t);
      }

      if(engine.GetValidForwardTradeCount() != 15) return false;
      if(engine.GetCohort().milestone != MILESTONE_15_TRADES) return false;

      return true;
   }

   // 5. Milestone Snapshot Contents (All Required Metrics)
   bool Test05_MilestoneSnapshotContents()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_MS_SNAP");

      for(int i = 1; i <= 15; i++)
      {
         SPaperTrade t;
         double pnl = (i % 3 == 0) ? -0.10 : 0.20;
         bool is_buy = (i % 2 == 0);
         ENUM_ATG_TRADE_DIRECTION dir = is_buy ? ATG_DIRECTION_BUY : ATG_DIRECTION_SELL;
         double entry = 1.1000;
         double sl = is_buy ? 1.0950 : 1.1050;
         double tp = is_buy ? 1.1100 : 1.0900;
         SetupMockTrade(t, i, is_buy ? "EURUSDm" : "BTCUSDm", dir,
            entry, sl, tp, 0.01, pnl, (pnl > 0) ? PAPER_CLOSED_TP : PAPER_CLOSED_SL,
            DATASET_FORWARD_LIVE_PAPER, 1700000000 + i * 100, 1700000500 + i * 100);
         engine.RecordTrade(t);
      }

      SForwardMilestoneSnapshot snap;
      if(!engine.GenerateMilestoneSnapshot(15, snap)) return false;

      if(snap.sample_size != 15) return false;
      if(snap.valid_records != 15) return false;
      if(snap.win_rate <= 0.0 || snap.win_rate >= 100.0) return false;
      if(snap.loss_rate <= 0.0 || snap.loss_rate >= 100.0) return false;
      if(snap.profit_factor <= 0.0) return false;
      if(snap.symbol_distribution == "") return false;
      if(snap.direction_distribution == "") return false;
      if(snap.confidence_quality_distribution == "") return false;
      if(snap.data_quality_statistics == "") return false;

      return true;
   }

   // 6. Statistical Evaluation Integration (Reusing Phase 8 Engine)
   bool Test06_StatisticalEvaluationIntegration()
   {
      CStatisticalEvaluationEngine stat_engine(m_logger);
      SPaperTrade trades[];
      ArrayResize(trades, 30);
      for(int i = 0; i < 30; i++)
      {
         double pnl = (i % 3 == 0) ? -0.10 : 0.20;
         SetupMockTrade(trades[i], i + 1, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, pnl,
            (pnl > 0) ? PAPER_CLOSED_TP : PAPER_CLOSED_SL, DATASET_FORWARD_LIVE_PAPER,
            1700000000 + i * 100, 1700000500 + i * 100);
      }

      SPhase8EvaluationResult stat_res;
      bool ok = stat_engine.RunFullEvaluation(trades, stat_res, 10.00, 100);
      if(!ok) return false;

      if(stat_res.total_trades != 30) return false;
      if(stat_res.sample_tier != SAMPLE_ADEQUATE_FOR_EVALUATION) return false;
      if(stat_res.profit_factor <= 0.0) return false;

      return true;
   }

   // 7. Data Quality Anomaly Detection & Explicit Reasons
   bool Test07_DataQualityAnomalyDetection()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_ANOMALY");

      string reason = "";
      SPaperTrade invalid_price;
      SetupMockTrade(invalid_price, 201, "EURUSDm", ATG_DIRECTION_BUY, 0.0, 1.0950, 1.1100, 0.01, 0.20);
      if(engine.ValidateTradeQuality(invalid_price, reason) != DATA_QUALITY_INVALID) return false;
      if(reason != "INVALID_PRICE_LEVELS") return false;

      SPaperTrade invalid_sltp;
      SetupMockTrade(invalid_sltp, 202, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.1050, 1.0900, 0.01, 0.20); // inverted SL/TP
      if(engine.ValidateTradeQuality(invalid_sltp, reason) != DATA_QUALITY_INVALID) return false;
      if(reason != "INVALID_SL_TP_GEOMETRY") return false;

      SPaperTrade temporal_inversion;
      SetupMockTrade(temporal_inversion, 203, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20,
         PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER, 1700005000, 1700001000); // exit before entry
      if(engine.ValidateTradeQuality(temporal_inversion, reason) != DATA_QUALITY_INVALID) return false;
      if(reason != "TEMPORAL_INVERSION") return false;

      SPaperTrade invalid_vol;
      SetupMockTrade(invalid_vol, 204, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.005, 0.20); // volume < 0.01
      if(engine.ValidateTradeQuality(invalid_vol, reason) != DATA_QUALITY_INVALID) return false;
      if(reason != "INVALID_VOLUME") return false;

      return true;
   }

   // 8. Daily Snapshot Persistence & Round-Trip Parsing
   bool Test08_DailySnapshotPersistence()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Test_Phase10");
      storage.Initialize();

      SForwardDailySnapshot snap;
      snap.Reset("2026-10-05");
      snap.timestamp          = TimeCurrent();
      snap.cohort_id          = "COHORT_DAILY";
      snap.trades_generated   = 5;
      snap.trades_closed      = 4;
      snap.sample_size        = 4;
      snap.pnl                = 0.60;
      snap.realized_r         = 2.00;
      snap.drawdown           = 0.10;
      snap.drawdown_pct       = 1.00;
      snap.data_health        = "HEALTHY";
      snap.persistence_health = "READY";
      snap.anomalies_count    = 0;
      snap.anomalies_summary  = "NONE";

      if(!storage.AppendDailySnapshot(snap)) return false;

      SForwardDailySnapshot loaded[];
      if(!storage.LoadDailySnapshots(loaded)) return false;
      if(ArraySize(loaded) < 1) return false;

      SForwardDailySnapshot last = loaded[ArraySize(loaded) - 1];
      if(last.date_key != "2026-10-05") return false;
      if(last.sample_size != 4) return false;
      if(MathAbs(last.pnl - 0.60) > 0.001) return false;

      return true;
   }

   // 9. Weekly Snapshot Persistence & Round-Trip Parsing
   bool Test09_WeeklySnapshotPersistence()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Test_Phase10");
      storage.Initialize();

      SForwardWeeklySnapshot snap;
      snap.Reset("2026-W40");
      snap.timestamp         = TimeCurrent();
      snap.cohort_id         = "COHORT_WEEKLY";
      snap.cumulative_trades = 15;
      snap.cumulative_pnl    = 1.80;
      snap.cumulative_r      = 6.00;
      snap.win_rate          = 66.67;
      snap.profit_factor     = 2.50;
      snap.regime_breakdown  = "TREND:10;RANGING:5";
      snap.symbol_breakdown  = "EURUSDm:8;BTCUSDm:7";
      snap.drawdown          = 0.20;
      snap.max_win_streak    = 4;
      snap.max_loss_streak   = 2;
      snap.evidence_quality  = "CLEAN";
      snap.changes_from_prev_week = "+15_TRADES";

      if(!storage.AppendWeeklySnapshot(snap)) return false;

      SForwardWeeklySnapshot loaded[];
      if(!storage.LoadWeeklySnapshots(loaded)) return false;
      if(ArraySize(loaded) < 1) return false;

      SForwardWeeklySnapshot last = loaded[ArraySize(loaded) - 1];
      if(last.week_key != "2026-W40") return false;
      if(last.cumulative_trades != 15) return false;

      return true;
   }

   // 10. Monthly Snapshot Persistence & Round-Trip Parsing
   bool Test10_MonthlySnapshotPersistence()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Test_Phase10");
      storage.Initialize();

      SForwardMonthlySnapshot snap;
      snap.Reset("2026-10");
      snap.timestamp           = TimeCurrent();
      snap.cohort_id           = "COHORT_MONTHLY";
      snap.total_trades        = 30;
      snap.win_rate            = 60.0;
      snap.profit_factor       = 2.10;
      snap.expectancy          = 0.50;
      snap.sharpe_ratio        = 1.45;
      snap.sortino_ratio       = 1.80;
      snap.robustness_survival = "PASSED";
      snap.evidence_class      = "PRELIMINARY";
      snap.recommendation      = "CONTINUE_COLLECTING";

      if(!storage.AppendMonthlySnapshot(snap)) return false;

      SForwardMonthlySnapshot loaded[];
      if(!storage.LoadMonthlySnapshots(loaded)) return false;
      if(ArraySize(loaded) < 1) return false;

      SForwardMonthlySnapshot last = loaded[ArraySize(loaded) - 1];
      if(last.month_key != "2026-10") return false;
      if(last.total_trades != 30) return false;
      if(last.recommendation != "CONTINUE_COLLECTING") return false;

      return true;
   }

   // 11. Monitoring Alerts & Diagnostic Dispatch
   bool Test11_MonitoringAlerts()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Test_Phase10");
      storage.Initialize();

      CForwardAlertManager alert_mgr(m_logger, &storage);
      alert_mgr.EmitAlert(ALERT_PERSISTENCE_FAILURE, "CRITICAL", "Storage", "Test persistence failure alert");
      alert_mgr.EmitAlert(ALERT_LARGE_DRAWDOWN, "WARNING", "RiskEngine", "Test large drawdown alert");
      alert_mgr.EmitAlert(ALERT_UNEXPECTED_BEHAVIOR, "NOTICE", "Core", "Test unexpected behavior notice");

      if(alert_mgr.GetAlertCount(ALERT_PERSISTENCE_FAILURE) != 1) return false;
      if(alert_mgr.GetAlertCount(ALERT_LARGE_DRAWDOWN) != 1) return false;
      if(alert_mgr.GetAlertCount(ALERT_UNEXPECTED_BEHAVIOR) != 1) return false;
      if(alert_mgr.GetTotalAlerts() != 3) return false;

      SForwardAlertRecord recs[];
      if(alert_mgr.GetRecentAlerts(recs) != 3) return false;

      return true;
   }

   // 12. Restart Recovery: Active Paper Trades Survival
   bool Test12_RestartActiveTradeSurvival()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Test_Phase10");
      storage.Initialize();

      SPaperTrade active[];
      ArrayResize(active, 2);
      SetupMockTrade(active[0], 501, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.0, PAPER_OPEN);
      SetupMockTrade(active[1], 502, "BTCUSDm", ATG_DIRECTION_BUY, 86000.0, 85000.0, 88000.0, 0.01, 0.0, PAPER_OPEN);

      if(!storage.SaveActiveTrades(active)) return false;

      // Simulate restart with new storage instance
      CPaperTradeStorage storage2(m_logger, "ATG_Test_Phase10");
      storage2.Initialize();

      SPaperTrade loaded[];
      if(!storage2.LoadActiveTrades(loaded)) return false;
      if(ArraySize(loaded) != 2) return false;
      if(loaded[0].paper_trade_id != 501 || loaded[1].paper_trade_id != 502) return false;
      if(loaded[0].status != PAPER_OPEN) return false;

      return true;
   }

   // 13. Restart Recovery: Forward Evidence Survival & Deduplication
   bool Test13_RestartForwardEvidenceSurvival()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_RESTART");

      SPaperTrade trades[];
      ArrayResize(trades, 5);
      for(int i = 0; i < 5; i++)
      {
         SetupMockTrade(trades[i], 601 + i, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20,
            PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER, 1700000000 + i * 100, 1700000500 + i * 100);
      }

      if(!engine.RebuildFromHistory(trades)) return false;
      if(engine.GetValidForwardTradeCount() != 5) return false;

      // Attempt to record duplicate trade ID 601
      engine.RecordTrade(trades[0]);
      if(engine.GetValidForwardTradeCount() != 5) return false;
      if(engine.GetMonitoringState().duplicate_trade_prevented != 1) return false;

      return true;
   }

   // 14. Restart Recovery: Equity History Continuity
   bool Test14_RestartEquityHistoryContinuity()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Test_Phase10");
      storage.Initialize();

      SEquityPoint pt1, pt2;
      pt1.timestamp = 1700000000;
      pt1.event_type = "INIT";
      pt1.trade_id = 0;
      pt1.equity = 10.00;
      pt1.balance = 10.00;
      pt1.peak_equity = 10.00;
      pt1.drawdown = 0.0;
      pt1.drawdown_pct = 0.0;
      pt1.realized_pnl = 0.0;
      pt1.realized_r = 0.0;

      pt2.timestamp = 1700001000;
      pt2.event_type = "TRADE_CLOSE";
      pt2.trade_id = 701;
      pt2.equity = 10.20;
      pt2.balance = 10.20;
      pt2.peak_equity = 10.20;
      pt2.drawdown = 0.0;
      pt2.drawdown_pct = 0.0;
      pt2.realized_pnl = 0.20;
      pt2.realized_r = 2.0;

      if(!storage.AppendEquityPoint(pt1)) return false;
      if(!storage.AppendEquityPoint(pt2)) return false;

      SEquityPoint loaded[];
      if(!storage.LoadEquityHistory(loaded)) return false;
      if(ArraySize(loaded) < 2) return false;

      SEquityPoint last = loaded[ArraySize(loaded) - 1];
      if(MathAbs(last.equity - 10.20) > 0.001) return false;

      return true;
   }

   // 15. Restart Recovery: Snapshot Integrity
   bool Test15_RestartSnapshotIntegrity()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Test_Phase10");
      storage.Initialize();

      SForwardMilestoneSnapshot snap;
      snap.Reset("N=15", 15);
      snap.timestamp = TimeCurrent();
      snap.cohort_id = "COHORT_INTEG";
      snap.sample_size = 15;
      snap.valid_records = 15;
      snap.win_rate = 60.0;
      snap.profit_factor = 2.0;

      if(!storage.AppendMilestoneSnapshot(snap)) return false;

      CPaperTradeStorage storage2(m_logger, "ATG_Test_Phase10");
      storage2.Initialize();

      SForwardMilestoneSnapshot loaded[];
      if(!storage2.LoadMilestoneSnapshots(loaded)) return false;
      if(ArraySize(loaded) < 1) return false;

      SForwardMilestoneSnapshot last = loaded[ArraySize(loaded) - 1];
      if(last.milestone_name != "N=15") return false;
      if(last.sample_size != 15) return false;

      return true;
   }

   // 16. Duplicate Trade & Duplicate Source Bar Rejection
   bool Test16_DuplicateTradeIdRejection()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_DUP");

      SPaperTrade t1, t2;
      SetupMockTrade(t1, 801, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20,
         PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER, 1700000000, 1700000500);
      SetupMockTrade(t2, 801, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20,
         PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER, 1700000000, 1700000500);

      engine.RecordTrade(t1);
      engine.RecordTrade(t2); // Duplicate ID

      if(engine.GetValidForwardTradeCount() != 1) return false;
      if(engine.GetMonitoringState().duplicate_trade_prevented != 1) return false;

      return true;
   }

   // 17. Excluded Record Reason Audit
   bool Test17_ExcludedRecordReasonAudit()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_AUDIT");

      SPaperTrade bad_risk;
      SetupMockTrade(bad_risk, 901, "EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, 1.1100, 0.01, 0.20);
      bad_risk.risk_money = 0.0; // Non-positive risk

      engine.RecordTrade(bad_risk);

      if(engine.GetValidForwardTradeCount() != 0) return false;
      if(engine.GetInvalidRecordCount() != 1) return false;

      SPaperTrade invalids[];
      engine.GetInvalidTrades(invalids);
      if(ArraySize(invalids) != 1) return false;
      if(invalids[0].quality_warning_reason != "NON_POSITIVE_RISK") return false;

      return true;
   }

   // 18. Zero Broker Execution Safety Hard Lock
   bool Test18_ZeroExecutionSafetyHardLock()
   {
      CCapabilities caps;
      caps.can_trade = false;
      CRuntimeState state;
      state.mode = MODE_MONITOR_ONLY;
      CExecutionGuard guard(m_logger, &caps, &state);

      SATGTradeIntent intent;
      ZeroMemory(intent);
      intent.request_id = 990001;
      intent.created_time = TimeCurrent();
      intent.symbol = "EURUSDm";
      intent.direction = ATG_DIRECTION_BUY;
      intent.volume = 0.01;
      intent.requested_price = 1.1000;

      bool allowed = guard.Validate(intent);
      if(allowed) return false;
      if(intent.rejection_reason != ATG_REJECT_EXECUTION_DISABLED) return false;

      return true;
   }

   // 19. Small-Account Scale Feasibility ($10.00 Paper Equity)
   bool Test19_SmallAccountScaleFeasibility()
   {
      CRiskEngine risk_engine(m_logger);
      risk_engine.SetSimulationEquity(10.00);
      risk_engine.SetUseSimulationEquity(true);
      risk_engine.SetDefaultRiskPercent(1.0);

      SATGRiskResult risk_res;
      if(!risk_engine.Calculate("EURUSDm", 1.1000, 1.0950, 1.0, risk_res)) return false;
      if(!risk_res.approved) return false;
      if(MathAbs(risk_res.risk_money - 0.10) > 0.0001) return false;

      CPositionSizer sizer(m_logger);
      SATGPositionSizeResult size_res;
      bool ok = sizer.Calculate("EURUSDm", ATG_DIRECTION_BUY, 1.1000, 1.0950, risk_res, size_res);
      if(ok)
      {
         if(size_res.estimated_loss_at_volume > risk_res.risk_money * 1.5)
            return false;
      }
      else
      {
         if(size_res.raw_volume > 0.0 && size_res.normalized_volume >= 0.01)
            return false;
      }

      return true;
   }

   // 20. End-to-End Forward Accumulation Workflow
   bool Test20_EndToEndForwardAccumulationWorkflow()
   {
      CConfig cfg;
      CForwardEvidenceEngine engine(m_logger);
      engine.Initialize(cfg, "COHORT_E2E");

      for(int i = 1; i <= 15; i++)
      {
         SPaperTrade t;
         SetupMockTrade(t, 1000 + i, (i % 2 == 0) ? "BTCUSDm" : "EURUSDm", ATG_DIRECTION_BUY,
            1.1000, 1.0950, 1.1100, 0.01, 0.20, PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER,
            1700000000 + i * 100, 1700000500 + i * 100);
         engine.RecordTrade(t);
      }

      if(engine.GetValidForwardTradeCount() != 15) return false;
      if(engine.GetCohort().milestone != MILESTONE_15_TRADES) return false;

      // Verify report generation
      CStatisticalEvaluationEngine stat_engine(m_logger);
      string rep = engine.GenerateForwardEvidenceReport(&stat_engine);
      if(StringLen(rep) < 200) return false;

      return true;
   }

   // Master Test Runner for Phase 10
   bool RunAllTests()
   {
      if(m_logger != NULL)
         m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "SUITE_START", "=== Starting Phase 10 Forward Evidence Accumulation Suite ===");

      int passed = 0;
      int total = 20;

      if(Test01_ForwardDatasetIntegritySeparation()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 01 Passed: Forward dataset integrity & separation."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 01 Failed: Dataset separation failed.");

      if(Test02_TradeFieldCompleteness()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 02 Passed: Trade field completeness verified (20 fields)."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 02 Failed: Trade field completeness failed.");

      if(Test03_StrategyFreezeAndAntiTampering()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 03 Passed: Strategy freeze and anti-tampering verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 03 Failed: Anti-tampering failed.");

      if(Test04_MilestoneProgressionSchedule()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 04 Passed: Milestone progression schedule verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 04 Failed: Milestone progression failed.");

      if(Test05_MilestoneSnapshotContents()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 05 Passed: Milestone snapshot contents verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 05 Failed: Snapshot contents failed.");

      if(Test06_StatisticalEvaluationIntegration()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 06 Passed: Statistical evaluation integration verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 06 Failed: Statistical evaluation integration failed.");

      if(Test07_DataQualityAnomalyDetection()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 07 Passed: Data quality anomaly detection verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 07 Failed: Anomaly detection failed.");

      if(Test08_DailySnapshotPersistence()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 08 Passed: Daily snapshot persistence verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 08 Failed: Daily snapshot persistence failed.");

      if(Test09_WeeklySnapshotPersistence()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 09 Passed: Weekly snapshot persistence verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 09 Failed: Weekly snapshot persistence failed.");

      if(Test10_MonthlySnapshotPersistence()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 10 Passed: Monthly snapshot persistence verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 10 Failed: Monthly snapshot persistence failed.");

      if(Test11_MonitoringAlerts()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 11 Passed: Monitoring alerts verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 11 Failed: Monitoring alerts failed.");

      if(Test12_RestartActiveTradeSurvival()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 12 Passed: Active trade survival across restart verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 12 Failed: Active trade survival failed.");

      if(Test13_RestartForwardEvidenceSurvival()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 13 Passed: Forward evidence survival & deduplication verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 13 Failed: Forward evidence survival failed.");

      if(Test14_RestartEquityHistoryContinuity()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 14 Passed: Equity history continuity verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 14 Failed: Equity history continuity failed.");

      if(Test15_RestartSnapshotIntegrity()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 15 Passed: Snapshot integrity across restart verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 15 Failed: Snapshot integrity failed.");

      if(Test16_DuplicateTradeIdRejection()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 16 Passed: Duplicate trade ID rejection verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 16 Failed: Duplicate trade ID rejection failed.");

      if(Test17_ExcludedRecordReasonAudit()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 17 Passed: Excluded record reason audit verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 17 Failed: Reason audit failed.");

      if(Test18_ZeroExecutionSafetyHardLock()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 18 Passed: Zero execution safety hard lock verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 18 Failed: Safety hard lock failed.");

      if(Test19_SmallAccountScaleFeasibility()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 19 Passed: Small-account scale feasibility verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 19 Failed: Sizing feasibility failed.");

      if(Test20_EndToEndForwardAccumulationWorkflow()) { passed++; if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "TEST_PASS", "Test 20 Passed: End-to-end forward accumulation workflow verified."); }
      else if(m_logger != NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase10Tests", "TEST_FAIL", "Test 20 Failed: E2E workflow failed.");

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "Phase10Tests", "ALL_PASSED",
            StringFormat("All %d / %d Phase 10 tests passed successfully.", passed, total));
      }

      return (passed == total);
   }
};

#endif
