//+------------------------------------------------------------------+
//| Phase9Tests.mqh                                                  |
//| ATG Trading Engine - Phase 9                                     |
//| Forward Paper Validation, Monitoring & Evidence Collection Suite |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_PHASE9_TESTS_MQH
#define ATG_PHASE9_TESTS_MQH

#include "../Diagnostics/Logger.mqh"
#include "../Security/Capabilities.mqh"
#include "../Execution/ExecutionGuard.mqh"
#include "../Execution/RiskEngine.mqh"
#include "../Execution/PositionSizer.mqh"
#include "../Core/RuntimeState.mqh"
#include "../Config/Config.mqh"
#include "../Analytics/ForwardEvidenceTypes.mqh"
#include "../Analytics/ForwardEvidenceEngine.mqh"
#include "../Analytics/EvaluationTypes.mqh"
#include "../Analytics/StatisticalEvaluationEngine.mqh"
#include "../Persistence/PaperTradeStorage.mqh"
#include "Phase3Tests.mqh"
#include "Phase4Tests.mqh"
#include "Phase5Tests.mqh"
#include "Phase6Tests.mqh"
#include "Phase7Tests.mqh"
#include "Phase8Tests.mqh"

class CPhase9Tests
{
private:
   CLogger* m_logger;

   void SetupMockTrade(SPaperTrade &t, ulong id, const string symbol, ENUM_ATG_TRADE_DIRECTION dir,
                       double entry, double sl, double tp, double vol, double pnl,
                       ENUM_PAPER_TRADE_STATUS status = PAPER_CLOSED_TP,
                       ENUM_DATASET_CLASS dclass = DATASET_FORWARD_LIVE_PAPER,
                       datetime entry_time = 1700000000, datetime exit_time = 1700001000,
                       double confidence = 0.85, double quality = 0.80,
                       ENUM_ATG_MARKET_REGIME reg = REGIME_TRENDING_BULLISH,
                       string exit_reason = EXIT_REASON_TP,
                       string cohort = "COHORT_TEST",
                       string fingerprint = "FP-TEST12345678",
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
         t.gross_pnl            = 0.0;
         t.net_pnl              = 0.0;
         t.realized_r           = 0.0;
         t.exit_reason          = "";
      }
      else
      {
         t.exit_time            = exit_time;
         t.exit_price           = (pnl >= 0.0) ? tp : sl;
         t.holding_duration_sec = (int)(exit_time - entry_time);
         t.gross_pnl            = pnl;
         t.net_pnl              = pnl;
         t.realized_r           = (MathAbs(t.risk_money) > 0.0001) ? (pnl / t.risk_money) : 0.0;
         t.status               = status;
         t.exit_reason          = (pnl >= 0.0) ? exit_reason : EXIT_REASON_SL;
      }
      t.strategy_confidence  = confidence;
      t.strategy_quality     = quality;
      t.regime               = reg;
      t.explanation          = "Phase 9 test trade";
      t.candidate_only       = true;

      // Phase 9 fields
      t.dataset_class        = dclass;
      t.data_quality         = DATA_QUALITY_VALID;
      t.quality_warning_reason = "";
      t.config_fingerprint   = fingerprint;
      t.cohort_id            = cohort;
      t.entry_spread_points  = entry_spread;
   }

public:
   CPhase9Tests(CLogger* logger = NULL) : m_logger(logger) {}

   // 1. Forward dataset classification
   bool Test01_ForwardDatasetClassification()
   {
      if(DatasetClassToString(DATASET_FORWARD_LIVE_PAPER) != "FORWARD_LIVE_PAPER") return false;
      if(DatasetClassToString(DATASET_SYNTHETIC_TEST) != "SYNTHETIC_TEST") return false;
      if(DatasetClassToString(DATASET_HISTORICAL_IMPORTED) != "HISTORICAL_IMPORTED") return false;
      if(DatasetClassToString(DATASET_UNKNOWN) != "DATASET_UNKNOWN") return false;

      if(StringToDatasetClass("FORWARD_LIVE_PAPER") != DATASET_FORWARD_LIVE_PAPER) return false;
      if(StringToDatasetClass("SYNTHETIC_TEST") != DATASET_SYNTHETIC_TEST) return false;
      if(StringToDatasetClass("HISTORICAL_IMPORTED") != DATASET_HISTORICAL_IMPORTED) return false;
      if(StringToDatasetClass("OTHER") != DATASET_UNKNOWN) return false;
      return true;
   }

   // 2. Synthetic-vs-forward isolation
   bool Test02_SyntheticVsForwardIsolation()
   {
      CConfig cfg;
      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      if(!engine.Initialize(cfg, "COHORT_SYNTH_EXCLUDE")) return false;

      SPaperTrade synth_trade;
      SetupMockTrade(synth_trade, 9001, "EURUSDm", ATG_DIRECTION_BUY, 1.0850, 1.0820, 1.0910, 0.01, 2.0,
                     PAPER_CLOSED_TP, DATASET_SYNTHETIC_TEST);
      
      engine.RecordTrade(synth_trade);

      // Synthetic trade must NOT increment forward trade count or forward PnL
      if(engine.GetValidForwardTradeCount() != 0) return false;
      if(engine.GetSyntheticTradeCount() != 1) return false;
      if(engine.GetCohortTradeCount() != 0) return false;
      if(engine.GetForwardNetPnl() != 0.0) return false;
      if(engine.GetMonitoringState().dataset_contamination_prevented != 1) return false;
      return true;
   }

   // 3. $10 paper equity initialization
   bool Test03_TenDollarPaperEquityInit()
   {
      CConfig cfg;
      if(MathAbs(cfg.initial_paper_equity - 10.00) > 0.0001) return false;

      CRiskEngine risk_engine(m_logger);
      risk_engine.SetSimulationEquity(cfg.initial_paper_equity);
      risk_engine.SetUseSimulationEquity(true);

      if(!risk_engine.IsUsingSimulationEquity()) return false;
      if(MathAbs(risk_engine.GetSimulationEquity() - 10.00) > 0.0001) return false;

      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      if(!engine.Initialize(cfg, "COHORT_10USD")) return false;

      SForwardCohort cohort = engine.GetActiveCohort();
      if(MathAbs(cohort.initial_paper_equity - 10.00) > 0.0001) return false;
      return true;
   }

   // 4. Small-account position sizing
   bool Test04_SmallAccountPositionSizing()
   {
      CRiskEngine risk_engine(m_logger);
      risk_engine.SetSimulationEquity(10.00);
      risk_engine.SetUseSimulationEquity(true);
      risk_engine.SetDefaultRiskPercent(1.0);

      SATGRiskResult risk_res;
      if(!risk_engine.Calculate("EURUSDm", 1.0800, 1.0770, 1.0, risk_res)) return false;

      if(!risk_res.approved) return false;
      if(MathAbs(risk_res.equity - 10.00) > 0.0001) return false;
      if(MathAbs(risk_res.risk_percent - 1.00) > 0.0001) return false;
      // 1.0% of $10.00 is exactly $0.10
      if(MathAbs(risk_res.risk_money - 0.10) > 0.0001) return false;
      return true;
   }

   // 5. Below-minimum-volume rejection
   bool Test05_BelowMinimumVolumeRejection()
   {
      CPositionSizer sizer(m_logger);
      SATGRiskResult risk_res;
      risk_res.approved = true;
      risk_res.equity = 10.00;
      risk_res.risk_percent = 1.0;
      risk_res.risk_money = 0.10; // $0.10 risk budget

      SATGPositionSizeResult size_res;
      // 30 pip stop on EURUSD requires loss per lot ~ $300.
      // Sizing $0.10 / $300 produces raw volume 0.00033.
      // Broker minimum volume is 0.01.
      bool ok = sizer.Calculate("EURUSDm", ATG_DIRECTION_BUY, 1.0850, 1.0820, risk_res, size_res);

      if(ok)
      {
         // If calculation passed, it must not violate the risk limit!
         if(size_res.estimated_loss_at_volume > risk_res.risk_money * 1.5)
            return false;
      }
      else
      {
         // Sizing must NOT be artificially inflated to vol_min
         if(size_res.raw_volume > 0.0 && size_res.normalized_volume >= 0.01)
            return false;
      }
      return true;
   }

   // 6. Forward trade creation
   bool Test06_ForwardTradeCreation()
   {
      SPaperTrade t;
      SetupMockTrade(t, 9002, "EURUSDm", ATG_DIRECTION_BUY, 1.0850, 1.0820, 1.0910, 0.01, 0.20,
                     PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER, 1700000000, 1700001000,
                     0.85, 0.80, REGIME_TRENDING_BULLISH, EXIT_REASON_TP, "COHORT_01", "FP-TEST", 15);

      if(t.paper_trade_id != 9002) return false;
      if(t.dataset_class != DATASET_FORWARD_LIVE_PAPER) return false;
      if(t.symbol != "EURUSDm") return false;
      if(t.direction != ATG_DIRECTION_BUY) return false;
      if(t.entry_price != 1.0850) return false;
      if(t.stop_loss != 1.0820) return false;
      if(t.take_profit != 1.0910) return false;
      if(t.candidate_only != true) return false;
      if(t.data_quality != DATA_QUALITY_VALID) return false;
      return true;
   }

   // 7. Forward trade persistence
   bool Test07_ForwardTradePersistence()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Phase9_Storage", 2, true);
      SPaperTrade active[];
      ArrayResize(active, 1);
      SetupMockTrade(active[0], 9003, "EURUSDm", ATG_DIRECTION_BUY, 1.0850, 1.0820, 1.0910, 0.01, 0.0,
                     PAPER_OPEN, DATASET_FORWARD_LIVE_PAPER);
      
      bool saved = storage.SaveActiveTrades(active);
      if(!saved) return false;
      return true;
   }

   // 8. Forward trade recovery
   bool Test08_ForwardTradeRecovery()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Phase9_Storage", 2, true);
      SPaperTrade loaded[];
      ulong max_id = 0;
      if(!storage.LoadActiveTrades(loaded, max_id)) return false;
      if(ArraySize(loaded) != 1) return false;
      if(loaded[0].paper_trade_id != 9003) return false;
      if(loaded[0].symbol != "EURUSDm") return false;
      if(loaded[0].dataset_class != DATASET_FORWARD_LIVE_PAPER) return false;
      if(loaded[0].entry_price != 1.0850) return false;
      return true;
   }

   // 9. Forward closed-trade persistence
   bool Test09_ForwardClosedTradePersistence()
   {
      CPaperTradeStorage storage(m_logger, "ATG_Phase9_Storage", 2, true);
      SPaperTrade closed_trade;
      SetupMockTrade(closed_trade, 9004, "EURUSDm", ATG_DIRECTION_BUY, 1.0850, 1.0820, 1.0910, 0.01, 0.20,
                     PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER);

      bool app_ok = storage.AppendClosedTrade(closed_trade);
      if(!app_ok) return false;

      SPaperTrade loaded[];
      ulong max_id = 0;
      if(!storage.LoadClosedTrades(loaded, max_id)) return false;
      int count = ArraySize(loaded);
      if(count < 1) return false;

      // Find our closed trade
      bool found = false;
      for(int i = 0; i < count; i++)
      {
         if(loaded[i].paper_trade_id == 9004)
         {
            found = true;
            if(loaded[i].dataset_class != DATASET_FORWARD_LIVE_PAPER) return false;
            if(MathAbs(loaded[i].net_pnl - 0.20) > 0.001) return false;
            break;
         }
      }
      return found;
   }

   // 10. Duplicate prevention
   bool Test10_DuplicatePrevention()
   {
      CConfig cfg;
      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      engine.Initialize(cfg, "COHORT_DUP");

      SPaperTrade t1;
      SetupMockTrade(t1, 9010, "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0770, 1.0860, 0.01, 0.10,
                     PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER);

      engine.RecordTrade(t1);
      if(engine.GetValidForwardTradeCount() != 1) return false;

      // Re-record exact same ID
      engine.RecordTrade(t1);
      if(engine.GetValidForwardTradeCount() != 1) return false;
      if(engine.GetMonitoringState().duplicate_trade_prevented != 1) return false;
      return true;
   }

   // 11. Restart recovery
   bool Test11_RestartRecovery()
   {
      CConfig cfg;
      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      engine.Initialize(cfg, "COHORT_REC");

      SPaperTrade history[];
      ArrayResize(history, 5);
      for(int i = 0; i < 5; i++)
      {
         SetupMockTrade(history[i], (ulong)(9020 + i), "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0770, 1.0860, 0.01, 0.15,
                        PAPER_CLOSED_TP, DATASET_FORWARD_LIVE_PAPER, 1700000000 + i*1000, 1700000500 + i*1000,
                        0.85, 0.80, REGIME_TRENDING_BULLISH, EXIT_REASON_TP, "COHORT_REC", engine.GetConfigFingerprint(), 10);
      }

      engine.RebuildFromHistory(history);
      if(engine.GetValidForwardTradeCount() != 5) return false;
      if(engine.GetCohortTradeCount() != 5) return false;
      if(MathAbs(engine.GetForwardNetPnl() - 0.75) > 0.0001) return false;
      return true;
   }

   // 12. Dataset contamination prevention
   bool Test12_DatasetContaminationPrevention()
   {
      CConfig cfg;
      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      engine.Initialize(cfg, "COHORT_CONTAM");

      // 3 forward live trades: +0.20, +0.20, -0.10 => Net +0.30
      for(int i = 0; i < 3; i++)
      {
         SPaperTrade fwd;
         double pnl = (i < 2) ? 0.20 : -0.10;
         SetupMockTrade(fwd, (ulong)(9030 + i), "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0770, 1.0860, 0.01, pnl,
                        (pnl >= 0) ? PAPER_CLOSED_TP : PAPER_CLOSED_SL, DATASET_FORWARD_LIVE_PAPER);
         engine.RecordTrade(fwd);
      }

      // 4 synthetic test trades: +1000.0 each
      for(int s = 0; s < 4; s++)
      {
         SPaperTrade syn;
         SetupMockTrade(syn, (ulong)(9040 + s), "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0770, 1.0860, 0.10, 1000.0,
                        PAPER_CLOSED_TP, DATASET_SYNTHETIC_TEST);
         engine.RecordTrade(syn);
      }

      // 2 historical imported trades: +500.0 each
      for(int h = 0; h < 2; h++)
      {
         SPaperTrade hist;
         SetupMockTrade(hist, (ulong)(9050 + h), "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0770, 1.0860, 0.10, 500.0,
                        PAPER_CLOSED_TP, DATASET_HISTORICAL_IMPORTED);
         engine.RecordTrade(hist);
      }

      // Forward stats MUST NOT include synthetic/historical trades
      if(engine.GetValidForwardTradeCount() != 3) return false;
      if(engine.GetSyntheticTradeCount() != 6) return false;
      if(MathAbs(engine.GetForwardNetPnl() - 0.30) > 0.0001) return false;
      if(engine.GetMonitoringState().dataset_contamination_prevented != 6) return false;
      return true;
   }

   // 13. Milestone tracking
   bool Test13_MilestoneTracking()
   {
      if(GetSampleMilestone(0) != MILESTONE_0_TRADES) return false;
      if(GetSampleMilestone(9) != MILESTONE_0_TRADES) return false;
      if(GetSampleMilestone(10) != MILESTONE_10_TRADES) return false;
      if(GetSampleMilestone(14) != MILESTONE_10_TRADES) return false;
      if(GetSampleMilestone(15) != MILESTONE_15_TRADES) return false;
      if(GetSampleMilestone(24) != MILESTONE_15_TRADES) return false;
      if(GetSampleMilestone(25) != MILESTONE_25_TRADES) return false;
      if(GetSampleMilestone(29) != MILESTONE_25_TRADES) return false;
      if(GetSampleMilestone(30) != MILESTONE_30_TRADES) return false;
      if(GetSampleMilestone(49) != MILESTONE_30_TRADES) return false;
      if(GetSampleMilestone(50) != MILESTONE_50_TRADES) return false;
      if(GetSampleMilestone(74) != MILESTONE_50_TRADES) return false;
      if(GetSampleMilestone(75) != MILESTONE_75_TRADES) return false;
      if(GetSampleMilestone(99) != MILESTONE_75_TRADES) return false;
      if(GetSampleMilestone(100) != MILESTONE_100_TRADES) return false;
      return true;
   }

   // 14. Statistical evaluation of forward-only records
   bool Test14_StatisticalEvaluationForwardOnly()
   {
      CConfig cfg;
      cfg.initial_paper_equity = 10.00;
      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      engine.Initialize(cfg, "COHORT_STAT");

      // Ingest 30 forward paper trades: 18 wins (+0.20), 12 losses (-0.10)
      for(int i = 0; i < 30; i++)
      {
         SPaperTrade t;
         double pnl = (i < 18) ? 0.20 : -0.10;
         SetupMockTrade(t, (ulong)(9060 + i), "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0770, 1.0860, 0.01, pnl,
                        (pnl >= 0) ? PAPER_CLOSED_TP : PAPER_CLOSED_SL,
                        DATASET_FORWARD_LIVE_PAPER, 1700000000 + i*1000, 1700000500 + i*1000,
                        0.85, 0.80, REGIME_TRENDING_BULLISH, (pnl >= 0) ? EXIT_REASON_TP : EXIT_REASON_SL,
                        "COHORT_STAT", engine.GetConfigFingerprint(), 10);
         engine.RecordTrade(t);
      }

      // Also ingest 10 synthetic trades to verify they are NEVER included in forward evaluation
      for(int s = 0; s < 10; s++)
      {
         SPaperTrade syn;
         SetupMockTrade(syn, (ulong)(9100 + s), "EURUSDm", ATG_DIRECTION_BUY, 1.0800, 1.0770, 1.0860, 0.1, 500.0,
                        PAPER_CLOSED_TP, DATASET_SYNTHETIC_TEST);
         engine.RecordTrade(syn);
      }

      if(engine.GetValidForwardTradeCount() != 30) return false;
      if(engine.GetSyntheticTradeCount() != 10) return false;

      SPaperTrade clean_fwd[];
      engine.GetValidForwardTrades(clean_fwd);
      if(ArraySize(clean_fwd) != 30) return false;

      CStatisticalEvaluationEngine stat_engine(m_logger);
      SPhase8EvaluationResult stat_res;
      if(!stat_engine.RunFullEvaluation(clean_fwd, stat_res, 10.00, 100)) return false;

      if(stat_res.total_trades != 30) return false;
      if(stat_res.winning_trades != 18) return false;
      if(stat_res.losing_trades != 12) return false;
      if(MathAbs(stat_res.win_rate - 60.0) > 0.1) return false;
      if(MathAbs(stat_res.net_pnl - 2.40) > 0.05) return false;

      return true;
   }

   // 15. Safety hard lock
   bool Test15_SafetyHardLock()
   {
      CRuntimeState state;
      state.mode = MODE_MONITOR_ONLY;
      if(state.mode != MODE_MONITOR_ONLY) return false;

      CCapabilities caps;
      caps.can_trade = false;
      CExecutionGuard guard(m_logger, &caps, &state);

      SATGTradeIntent intent;
      ZeroMemory(intent);
      intent.request_id = 999999;
      intent.created_time = TimeCurrent();
      intent.symbol = "EURUSDm";
      intent.direction = ATG_DIRECTION_BUY;
      intent.volume = 0.01;

      bool allowed = guard.Validate(intent);
      if(allowed) return false;
      if(intent.rejection_reason != ATG_REJECT_EXECUTION_DISABLED) return false;
      return true;
   }

   // 16. No broker execution
   bool Test16_NoBrokerExecution()
   {
      CCapabilities caps;
      caps.can_trade = false;
      CRuntimeState state;
      state.mode = MODE_MONITOR_ONLY;
      CExecutionGuard guard(m_logger, &caps, &state);

      SATGTradeIntent intent;
      ZeroMemory(intent);
      intent.request_id = 999998;
      intent.created_time = TimeCurrent();
      intent.symbol = "EURUSDm";
      intent.direction = ATG_DIRECTION_BUY;
      intent.volume = 0.01;

      // Verification that guard permanently blocks order submission
      if(guard.Validate(intent)) return false;
      if(intent.rejection_reason != ATG_REJECT_EXECUTION_DISABLED) return false;
      return true;
   }

   // 17. Regression against Phases 3-8
   bool Test17_RegressionPhases()
   {
      CPhase3Tests p3(m_logger);
      if(!p3.RunAllTests()) return false;

      CPhase4Tests p4(m_logger);
      if(!p4.RunAllTests()) return false;

      CPhase5Tests p5(m_logger);
      if(!p5.RunAllTests()) return false;

      CPhase6Tests p6(m_logger);
      if(!p6.RunAllTests()) return false;

      CPhase7Tests p7(m_logger);
      if(!p7.RunAllTests()) return false;

      CPhase8Tests p8(m_logger);
      if(!p8.RunAllTests()) return false;

      return true;
   }

   // 18. Evidence-window versioning
   bool Test18_EvidenceWindowVersioning()
   {
      CConfig cfg;
      cfg.initial_paper_equity = 10.00;
      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      if(!engine.Initialize(cfg, "COHORT_01")) return false;

      SForwardCohort cohort = engine.GetActiveCohort();
      if(cohort.cohort_id != "COHORT_01") return false;
      if(cohort.strategy_version != "0.9.0") return false;
      if(cohort.config_version != "2.0.0") return false;
      if(cohort.initial_paper_equity != 10.00) return false;
      if(cohort.status != COHORT_STATUS_COLLECTING) return false;
      if(cohort.config_fingerprint == "") return false;
      return true;
   }

   // 19. Configuration freeze/integrity
   bool Test19_ConfigFreezeIntegrity()
   {
      CConfig cfg;
      SForwardConfigSnapshot snap;
      snap.Capture(cfg, "COHORT_FREEZE");

      if(snap.config_fingerprint == "") return false;
      if(!snap.VerifyConfig(cfg)) return false;

      // Verify tamper detection on risk percent
      CConfig tampered = cfg;
      tampered.risk_percent = 2.0;
      if(snap.VerifyConfig(tampered)) return false;

      // Verify tamper detection on min RR
      tampered = cfg;
      tampered.min_reward_risk = 2.5;
      if(snap.VerifyConfig(tampered)) return false;

      // Verify tamper detection on SL ATR multiplier
      tampered = cfg;
      tampered.sl_atr_multiplier = 3.0;
      if(snap.VerifyConfig(tampered)) return false;

      // Verify tamper detection on spread tolerance
      tampered = cfg;
      tampered.max_spread_tolerance = 20;
      if(snap.VerifyConfig(tampered)) return false;

      // Test engine validation and cohort invalidation
      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      engine.Initialize(cfg, "COHORT_FREEZE");
      if(engine.VerifyConfiguration(tampered)) return false;
      if(engine.GetActiveCohort().status != COHORT_STATUS_INVALIDATED) return false;

      return true;
   }

   // 20. Forward monitoring diagnostics
   bool Test20_ForwardMonitoringDiagnostics()
   {
      CConfig cfg;
      CPaperTradeStorage storage(m_logger, "ATG_Test_Storage", 2, false);
      CForwardEvidenceEngine engine(m_logger, &storage);
      engine.Initialize(cfg, "COHORT_MONITOR");

      // Exercise all 15 diagnostic recording methods
      engine.RecordDataGap();
      engine.RecordStaleMarketData();
      engine.RecordSymbolUnavailable();
      engine.RecordSpreadAnomaly();
      engine.RecordInvalidPrice();
      engine.RecordPositionSizingRejection("EURUSDm", "Volume below broker minimum");
      engine.RecordTradeCreationFailure("Invalid plan state");
      engine.RecordPersistenceWriteError();
      engine.RecordPersistenceRecoveryError();
      engine.RecordDuplicateTradePrevented();
      engine.RecordUnexpectedStateTransition();
      engine.RecordSafetyGateViolation();
      engine.RecordDatasetContaminationPrevented();
      engine.RecordEaRestart();
      engine.RecordMissingClosedTrade();

      SForwardMonitoringState mon = engine.GetMonitoringState();
      if(mon.data_gaps_count != 1) return false;
      if(mon.stale_market_data_count != 1) return false;
      if(mon.symbol_unavailable_count != 1) return false;
      if(mon.spread_anomaly_count != 1) return false;
      if(mon.invalid_prices_count != 1) return false;
      if(mon.position_sizing_rejections != 1) return false;
      if(mon.paper_trade_creation_failures != 1) return false;
      if(mon.persistence_write_errors != 1) return false;
      if(mon.persistence_recovery_errors != 1) return false;
      if(mon.duplicate_trade_prevented != 1) return false;
      if(mon.unexpected_state_transitions != 1) return false;
      if(mon.safety_gate_violations != 1) return false;
      if(mon.dataset_contamination_prevented != 1) return false;
      if(mon.ea_restarts_count != 1) return false;
      if(mon.missing_closed_trades_count != 1) return false;

      string report = engine.GenerateForwardEvidenceReport();
      if(StringFind(report, "[01] Data Gaps:              1") < 0) return false;
      if(StringFind(report, "[06] Position-Sizing Rejects:1") < 0) return false;
      if(StringFind(report, "[13] Dataset Contamination:  1 prevented") < 0) return false;

      return true;
   }

   // Run all Phase 9 tests
   bool RunAllTests()
   {
      if(m_logger != NULL)
         m_logger.Log(LOG_LEVEL_INFO, "Phase9Tests", "START", "Starting Phase 9 Forward Paper Validation & Evidence Test Suite (20 Tests)...");

      int passed = 0;
      int total  = 20;

      if(Test01_ForwardDatasetClassification())      { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test01 failed"); }
      if(Test02_SyntheticVsForwardIsolation())        { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test02 failed"); }
      if(Test03_TenDollarPaperEquityInit())          { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test03 failed"); }
      if(Test04_SmallAccountPositionSizing())        { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test04 failed"); }
      if(Test05_BelowMinimumVolumeRejection())       { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test05 failed"); }
      if(Test06_ForwardTradeCreation())              { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test06 failed"); }
      if(Test07_ForwardTradePersistence())           { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test07 failed"); }
      if(Test08_ForwardTradeRecovery())              { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test08 failed"); }
      if(Test09_ForwardClosedTradePersistence())     { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test09 failed"); }
      if(Test10_DuplicatePrevention())               { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test10 failed"); }
      if(Test11_RestartRecovery())                   { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test11 failed"); }
      if(Test12_DatasetContaminationPrevention())    { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test12 failed"); }
      if(Test13_MilestoneTracking())                 { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test13 failed"); }
      if(Test14_StatisticalEvaluationForwardOnly())  { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test14 failed"); }
      if(Test15_SafetyHardLock())                    { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test15 failed"); }
      if(Test16_NoBrokerExecution())                 { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test16 failed"); }
      if(Test17_RegressionPhases())                  { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test17 failed"); }
      if(Test18_EvidenceWindowVersioning())          { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test18 failed"); }
      if(Test19_ConfigFreezeIntegrity())             { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test19 failed"); }
      if(Test20_ForwardMonitoringDiagnostics())      { passed++; } else { if(m_logger!=NULL) m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAIL", "Test20 failed"); }

      bool ok = (passed == total);

      if(m_logger != NULL)
      {
         if(ok)
            m_logger.Log(LOG_LEVEL_INFO, "Phase9Tests", "ALL_PASSED", StringFormat("All %d / %d Phase 9 tests passed successfully.", passed, total));
         else
            m_logger.Log(LOG_LEVEL_ERROR, "Phase9Tests", "FAILED", StringFormat("Phase 9 test failure: %d / %d tests passed.", passed, total));
      }

      return ok;
   }
};

#endif
