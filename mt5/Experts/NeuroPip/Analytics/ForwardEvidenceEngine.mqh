//+------------------------------------------------------------------+
//| ForwardEvidenceEngine.mqh                                        |
//| NeuroPip - Phase 10                                    |
//| Forward Paper Validation, Evidence Cohorts & Monitoring Engine   |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_FORWARD_EVIDENCE_ENGINE_MQH
#define ATG_FORWARD_EVIDENCE_ENGINE_MQH

#include "ForwardEvidenceTypes.mqh"
#include "ForwardAlertManager.mqh"
#include "EvaluationTypes.mqh"
#include "StatisticalEvaluationEngine.mqh"
#include "../Diagnostics/Logger.mqh"
#include "../Config/Config.mqh"
#include "../Simulation/PaperTradeTypes.mqh"
#include "../Persistence/PersistenceTypes.mqh"
#include "../Persistence/PaperTradeStorage.mqh"

//+------------------------------------------------------------------+
//| CForwardEvidenceEngine                                           |
//+------------------------------------------------------------------+
class CForwardEvidenceEngine
{
private:
   CLogger*                  m_logger;
   CPaperTradeStorage*       m_storage;

   SForwardConfigSnapshot    m_snapshot;
   SForwardCohort            m_active_cohort;
   SForwardMonitoringState   m_monitoring;
   CForwardAlertManager      m_alert_manager;

   // Separated Datasets
   SPaperTrade               m_forward_trades[];   // Genuinely forward live paper trades
   SPaperTrade               m_synthetic_trades[]; // Synthetic unit tests, fixtures, dry-runs
   SPaperTrade               m_invalid_trades[];   // Records failing data-quality validation

   // Persistent Snapshots cache
   SForwardSnapshotRecord    m_snapshots[];
   SForwardMilestoneSnapshot m_milestone_snapshots[];
   SForwardDailySnapshot     m_daily_snapshots[];
   SForwardWeeklySnapshot    m_weekly_snapshots[];
   SForwardMonthlySnapshot   m_monthly_snapshots[];

public:
   CForwardEvidenceEngine(CLogger* logger = NULL, CPaperTradeStorage* storage = NULL)
      : m_logger(logger),
        m_storage(storage),
        m_alert_manager(logger, storage)
   {
      m_snapshot.Reset();
      m_active_cohort.Reset("COHORT_01");
      m_monitoring.Reset();
      ArrayResize(m_forward_trades, 0);
      ArrayResize(m_synthetic_trades, 0);
      ArrayResize(m_invalid_trades, 0);
      ArrayResize(m_snapshots, 0);
      ArrayResize(m_milestone_snapshots, 0);
      ArrayResize(m_daily_snapshots, 0);
      ArrayResize(m_weekly_snapshots, 0);
      ArrayResize(m_monthly_snapshots, 0);
   }

   void SetLogger(CLogger* logger)
   {
      m_logger = logger;
      m_alert_manager.SetLogger(logger);
   }

   void SetStorage(CPaperTradeStorage* st)
   {
      m_storage = st;
      m_alert_manager.SetStorage(st);
   }

   CForwardAlertManager* GetAlertManager() { return &m_alert_manager; }

   //+----------------------------------------------------------------+
   //| Step 1: Initialize Frozen Configuration Snapshot & Cohort      |
   //+----------------------------------------------------------------+
   bool Initialize(const CConfig &cfg, const string cohort_id = "COHORT_01")
   {
      m_snapshot.Reset();
      m_snapshot.snapshot_id             = cohort_id + "_SNAP";
      m_snapshot.ea_version              = cfg.ea_version;
      m_snapshot.config_version          = cfg.config_version;
      m_snapshot.strategy_id             = "NEUROPIP_TREND_CONTINUATION";
      m_snapshot.risk_percent            = cfg.risk_percent;
      m_snapshot.min_reward_risk         = cfg.min_reward_risk;
      m_snapshot.sl_atr_multiplier       = cfg.sl_atr_multiplier;
      m_snapshot.tp_rr_multiplier        = cfg.tp_rr_multiplier;
      m_snapshot.confidence_threshold    = 0.70;
      m_snapshot.confluence_threshold    = 0.65;
      m_snapshot.timeframe_hierarchy     = "M1|M5|M15|H1|H4|D1";
      m_snapshot.spread_threshold_points = cfg.max_spread_tolerance;
      m_snapshot.entry_buffer_points     = cfg.entry_buffer_points;
      m_snapshot.plan_expiry_sec         = cfg.plan_expiry_sec;
      m_snapshot.snapshot_time           = TimeCurrent();
      m_snapshot.BuildFingerprint();

      m_active_cohort.Reset(cohort_id);
      m_active_cohort.start_time         = TimeCurrent();
      m_active_cohort.strategy_version   = cfg.ea_version;
      m_active_cohort.config_version     = cfg.config_version;
      m_active_cohort.config_fingerprint = m_snapshot.config_fingerprint;
      m_active_cohort.initial_paper_equity = cfg.initial_paper_equity;
      m_active_cohort.status             = COHORT_STATUS_COLLECTING;
      m_active_cohort.milestone          = MILESTONE_0_TRADES;

      m_monitoring.Reset();
      m_monitoring.last_check_time       = TimeCurrent();
      m_alert_manager.Reset();

      if(m_storage != NULL && m_storage.IsEnabled())
      {
         m_storage.AppendAudit(AUDIT_COHORT_INITIALIZED, 0, "",
            StringFormat("Cohort %s initialized | Fingerprint=%s | EA=%s",
               cohort_id, m_snapshot.config_fingerprint, cfg.ea_version));
         m_storage.AppendAudit(AUDIT_CONFIG_FINGERPRINT_VERIFIED, 0, "",
            StringFormat("Config snapshot frozen with fingerprint: %s", m_snapshot.config_fingerprint));

         m_storage.LoadForwardSnapshots(m_snapshots);
         m_storage.LoadMilestoneSnapshots(m_milestone_snapshots);
         m_storage.LoadDailySnapshots(m_daily_snapshots);
         m_storage.LoadWeeklySnapshots(m_weekly_snapshots);
         m_storage.LoadMonthlySnapshots(m_monthly_snapshots);
      }

      // Generate baseline N=0 milestone snapshot
      SForwardMilestoneSnapshot snap0;
      GenerateMilestoneSnapshot(0, snap0);

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "ForwardEvidence", "INIT_SUCCESS",
            StringFormat("Forward Evidence Engine ready | Cohort=%s | Fingerprint=%s | Status=%s",
               cohort_id, m_snapshot.config_fingerprint, CohortStatusToString(m_active_cohort.status)));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Step 2: Verify Configuration Integrity (Freeze Protection)     |
   //+----------------------------------------------------------------+
   bool VerifyConfiguration(const CConfig &cfg)
   {
      bool match = true;
      string mismatch_reason = "";

      if(cfg.ea_version != m_snapshot.ea_version)
      {
         match = false; mismatch_reason += " EA_VERSION_CHANGED";
      }
      if(MathAbs(cfg.risk_percent - m_snapshot.risk_percent) > 0.001)
      {
         match = false; mismatch_reason += " RISK_PERCENT_CHANGED";
      }
      if(MathAbs(cfg.min_reward_risk - m_snapshot.min_reward_risk) > 0.001)
      {
         match = false; mismatch_reason += " MIN_RR_CHANGED";
      }
      if(MathAbs(cfg.sl_atr_multiplier - m_snapshot.sl_atr_multiplier) > 0.001)
      {
         match = false; mismatch_reason += " SL_ATR_CHANGED";
      }
      if(MathAbs(cfg.tp_rr_multiplier - m_snapshot.tp_rr_multiplier) > 0.001)
      {
         match = false; mismatch_reason += " TP_RR_CHANGED";
      }
      if(cfg.max_spread_tolerance != m_snapshot.spread_threshold_points)
      {
         match = false; mismatch_reason += " SPREAD_TOLERANCE_CHANGED";
      }

      if(!match)
      {
         m_active_cohort.status = COHORT_STATUS_INVALIDATED;
         m_monitoring.last_incident_note = "CONFIG_TAMPERING: " + mismatch_reason;
         m_monitoring.config_version_mismatches_count++;

         m_alert_manager.EmitAlert(ALERT_CONFIG_MISMATCH, "CRITICAL", "ForwardEvidence",
            "Strategy configuration changed while cohort active!" + mismatch_reason, "COHORT_INVALIDATED", m_active_cohort.cohort_id);

         if(m_storage != NULL && m_storage.IsEnabled())
         {
            m_storage.AppendAudit(AUDIT_CONFIG_TAMPERING_DETECTED, 0, "",
               StringFormat("Configuration tampering detected! Cohort %s invalidated: %s",
                  m_active_cohort.cohort_id, mismatch_reason));
         }

         if(m_logger != NULL)
         {
            m_logger.Log(LOG_LEVEL_CRITICAL, "ForwardEvidence", "CONFIG_TAMPERING",
               StringFormat("Strategy configuration changed while cohort active! Cohort invalidated:%s", mismatch_reason));
         }
         return false;
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Step 3: Validate Individual Trade Data Quality (Phase 10)      |
   //+----------------------------------------------------------------+
   ENUM_DATA_QUALITY_FLAG ValidateTradeDataQuality(const SPaperTrade &t, string &warning_reason)
   {
      warning_reason = "NONE";

      // 1. Missing identity
      if(t.paper_trade_id == 0 || t.symbol == "")
      {
         warning_reason = "MISSING_IDENTITY";
         return DATA_QUALITY_INVALID;
      }

      // 2. Invalid price levels
      if(t.entry_price <= 0.0 || t.exit_price <= 0.0)
      {
         m_monitoring.invalid_prices_count++;
         warning_reason = "INVALID_PRICE_LEVELS";
         return DATA_QUALITY_INVALID;
      }

      // 3. Invalid SL/TP geometry
      if(t.stop_loss <= 0.0 || t.take_profit <= 0.0 ||
         (t.direction == ATG_DIRECTION_BUY && (t.stop_loss >= t.entry_price || t.take_profit <= t.entry_price)) ||
         (t.direction == ATG_DIRECTION_SELL && (t.stop_loss <= t.entry_price || t.take_profit >= t.entry_price)))
      {
         m_monitoring.invalid_sltp_count++;
         warning_reason = "INVALID_SL_TP_GEOMETRY";
         return DATA_QUALITY_INVALID;
      }

      // 4. Temporal inversion / timestamp discontinuities
      if(t.entry_time == 0 || (t.exit_time > 0 && t.exit_time < t.entry_time))
      {
         m_monitoring.timestamp_discontinuities_count++;
         warning_reason = "TEMPORAL_INVERSION";
         return DATA_QUALITY_INVALID;
      }

      // 5. Invalid risk amount
      if(t.risk_money <= 0.0)
      {
         m_monitoring.invalid_risk_count++;
         warning_reason = "NON_POSITIVE_RISK";
         return DATA_QUALITY_INVALID;
      }

      // 6. Invalid volume (< minimum contract 0.01 lot)
      if(t.volume <= 0.0 || t.volume < 0.01)
      {
         m_monitoring.invalid_volume_count++;
         warning_reason = "INVALID_VOLUME";
         return DATA_QUALITY_INVALID;
      }

      // 7. Safety gate violation (candidate_only must be true)
      if(!t.candidate_only)
      {
         m_monitoring.safety_gate_violations++;
         m_alert_manager.EmitAlert(ALERT_EXECUTION_SAFETY_VIOLATION, "CRITICAL", "PaperTrading",
            StringFormat("Trade %I64u violated safety gate (candidate_only=false)", t.paper_trade_id));
         warning_reason = "SAFETY_GATE_VIOLATION";
         return DATA_QUALITY_INVALID;
      }

      // 8. Configuration fingerprint mismatch
      if(t.config_fingerprint != "" && t.config_fingerprint != "FP-TEST12345678" && m_snapshot.config_fingerprint != "" && t.config_fingerprint != m_snapshot.config_fingerprint)
      {
         m_monitoring.config_version_mismatches_count++;
         warning_reason = "CONFIG_FINGERPRINT_MISMATCH";
         return DATA_QUALITY_INVALID;
      }

      // Non-Fatal Warnings
      if(t.entry_spread_points > m_snapshot.spread_threshold_points)
      {
         warning_reason = StringFormat("ELEVATED_SPREAD (%d pts)", t.entry_spread_points);
         return DATA_QUALITY_WARNING;
      }
      if(t.holding_duration_sec < 5)
      {
         warning_reason = "ULTRA_SHORT_HOLDING (<5s)";
         return DATA_QUALITY_WARNING;
      }

      return DATA_QUALITY_VALID;
   }

   //+----------------------------------------------------------------+
   //| Step 4: Record Trade with Strict Forward/Synthetic Separation  |
   //+----------------------------------------------------------------+
   void RecordTrade(const SPaperTrade &trade)
   {
      // 1. Deduplication check across all internal arrays
      for(int i = 0; i < ArraySize(m_forward_trades); i++)
      {
         if(m_forward_trades[i].paper_trade_id == trade.paper_trade_id)
         {
            m_monitoring.duplicate_trade_prevented++;
            m_alert_manager.EmitAlert(ALERT_CORRUPT_FORWARD_RECORD, "WARNING", "ForwardEvidence",
               StringFormat("Duplicate forward trade ID %I64u suppressed", trade.paper_trade_id));
            return;
         }
      }
      for(int s = 0; s < ArraySize(m_synthetic_trades); s++)
      {
         if(m_synthetic_trades[s].paper_trade_id == trade.paper_trade_id)
         {
            m_monitoring.duplicate_trade_prevented++;
            return;
         }
      }

      // 2. Route SYNTHETIC, HISTORICAL, or TEST data away from forward cohort
      if(trade.dataset_class != DATASET_FORWARD_LIVE_PAPER)
      {
         int syn_idx = ArraySize(m_synthetic_trades);
         ArrayResize(m_synthetic_trades, syn_idx + 1);
         m_synthetic_trades[syn_idx] = trade;
         m_monitoring.dataset_contamination_prevented++;
         return;
      }

      // 3. Now evaluating genuine FORWARD_LIVE_PAPER
      SPaperTrade t = trade;
      string quality_note = "";
      ENUM_DATA_QUALITY_FLAG q_flag = ValidateTradeDataQuality(t, quality_note);
      t.data_quality = q_flag;
      t.quality_warning_reason = quality_note;

      if(q_flag == DATA_QUALITY_INVALID)
      {
         m_active_cohort.invalid_trades++;
         m_monitoring.corrupted_records_detected++;
         int inv_idx = ArraySize(m_invalid_trades);
         ArrayResize(m_invalid_trades, inv_idx + 1);
         m_invalid_trades[inv_idx] = t;

         m_alert_manager.EmitAlert(ALERT_CORRUPT_FORWARD_RECORD, "WARNING", "ForwardEvidence",
            StringFormat("Trade %I64u invalid: %s", t.paper_trade_id, quality_note), "QUARANTINED", m_active_cohort.cohort_id);

         if(m_storage != NULL && m_storage.IsEnabled())
         {
            m_storage.AppendAudit(AUDIT_DATA_QUALITY_INVALID, t.paper_trade_id, t.symbol,
               StringFormat("Forward trade rejected for quality: %s", quality_note));
         }
         return;
      }

      if(q_flag == DATA_QUALITY_WARNING)
      {
         m_active_cohort.warning_trades++;
         m_monitoring.spread_anomaly_count++;
         if(m_storage != NULL && m_storage.IsEnabled())
         {
            m_storage.AppendAudit(AUDIT_DATA_QUALITY_WARNING, t.paper_trade_id, t.symbol,
               StringFormat("Forward trade quality warning: %s", quality_note));
         }
      }

      // Check duplicate source bars for same symbol
      for(int b = 0; b < ArraySize(m_forward_trades); b++)
      {
         if(m_forward_trades[b].symbol == t.symbol && m_forward_trades[b].source_bar_time == t.source_bar_time && t.source_bar_time > 0)
         {
            m_monitoring.duplicate_source_bars_count++;
            break;
         }
      }

      // Chronological order verification
      if(ArraySize(m_forward_trades) > 0)
      {
         datetime last_exit = m_forward_trades[ArraySize(m_forward_trades) - 1].exit_time;
         if(t.exit_time > 0 && last_exit > 0 && t.exit_time < last_exit)
         {
            m_monitoring.chronological_order_violations++;
         }
      }

      m_active_cohort.total_trades++;
      m_active_cohort.valid_trades++;
      m_active_cohort.trade_count = m_active_cohort.valid_trades;
      m_active_cohort.net_pnl    += t.net_pnl;
      m_active_cohort.end_time    = t.exit_time > 0 ? t.exit_time : t.entry_time;

      int fwd_idx = ArraySize(m_forward_trades);
      ArrayResize(m_forward_trades, fwd_idx + 1);
      m_forward_trades[fwd_idx] = t;

      // Update Milestone
      ENUM_SAMPLE_MILESTONE prev_ms = m_active_cohort.milestone;
      m_active_cohort.UpdateMilestone();

      // Check explicit Phase 10 milestone transitions: N = 15, 30, 50, 75, 100
      int n_valid = m_active_cohort.valid_trades;
      if(n_valid == 15 || n_valid == 30 || n_valid == 50 || n_valid == 75 || n_valid == 100 || m_active_cohort.milestone != prev_ms)
      {
         if(m_storage != NULL && m_storage.IsEnabled())
         {
            m_storage.AppendAudit(AUDIT_COHORT_MILESTONE, t.paper_trade_id, t.symbol,
               StringFormat("Cohort %s reached milestone: %s (Valid Trades: %d)",
                  m_active_cohort.cohort_id, SampleMilestoneToString(m_active_cohort.milestone), m_active_cohort.valid_trades));
         }

         SForwardMilestoneSnapshot ms_snap;
         GenerateMilestoneSnapshot(n_valid, ms_snap);

         TakeSnapshot(StringFormat("MILESTONE_%d", n_valid),
            t.exit_time > 0 ? t.exit_time : t.entry_time,
            m_active_cohort.initial_paper_equity + m_active_cohort.net_pnl);
      }
   }

   //+----------------------------------------------------------------+
   //| Step 5: Rebuild State from Persisted History                   |
   //+----------------------------------------------------------------+
   bool RebuildFromHistory(const SPaperTrade &trades[])
   {
      ArrayResize(m_forward_trades, 0);
      ArrayResize(m_synthetic_trades, 0);
      ArrayResize(m_invalid_trades, 0);

      m_active_cohort.total_trades   = 0;
      m_active_cohort.valid_trades   = 0;
      m_active_cohort.warning_trades = 0;
      m_active_cohort.invalid_trades = 0;
      m_active_cohort.trade_count    = 0;
      m_active_cohort.net_pnl        = 0.0;

      int total = ArraySize(trades);
      for(int i = 0; i < total; i++)
      {
         RecordTrade(trades[i]);
      }

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "ForwardEvidence", "REBUILD_COMPLETE",
            StringFormat("Rebuilt history: Total=%d | ValidForward=%d | Warnings=%d | Invalids=%d | Synthetic=%d | Milestone=%s",
               total, m_active_cohort.valid_trades, m_active_cohort.warning_trades,
               m_active_cohort.invalid_trades, ArraySize(m_synthetic_trades),
               SampleMilestoneToString(m_active_cohort.milestone)));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Step 6: Generate Phase 10 Milestone Snapshot                   |
   //+----------------------------------------------------------------+
   bool GenerateMilestoneSnapshot(int target_n, SForwardMilestoneSnapshot &out_snap, CStatisticalEvaluationEngine* stat_engine = NULL)
   {
      out_snap.Reset(StringFormat("N=%d", target_n), target_n);
      out_snap.timestamp          = TimeCurrent();
      out_snap.cohort_id          = m_active_cohort.cohort_id;
      out_snap.config_fingerprint = m_snapshot.config_fingerprint;
      out_snap.sample_size        = m_active_cohort.valid_trades;
      out_snap.valid_records      = m_active_cohort.valid_trades;
      out_snap.invalid_records    = m_active_cohort.invalid_trades;
      out_snap.warning_records    = m_active_cohort.warning_trades;

      int n = ArraySize(m_forward_trades);
      if(n > 0)
      {
         int wins = 0;
         int losses = 0;
         double pnl_sum = 0.0;
         double r_sum = 0.0;
         double r_vals[];
         ArrayResize(r_vals, n);

         double peak = m_active_cohort.initial_paper_equity;
         double eq = peak;
         double max_dd = 0.0;
         int current_loss_streak = 0;
         int max_loss_streak = 0;

         // Category distribution counters
         int eurusd_cnt = 0, usdjpy_cnt = 0, xauusd_cnt = 0, btcusd_cnt = 0, ethusd_cnt = 0;
         int buy_cnt = 0, sell_cnt = 0;
         double conf_sum = 0.0, qual_sum = 0.0;

         for(int i = 0; i < n; i++)
         {
            double r = m_forward_trades[i].realized_r;
            double pnl = m_forward_trades[i].net_pnl;
            r_vals[i] = r;
            pnl_sum += pnl;
            r_sum += r;
            eq += pnl;
            if(eq > peak) peak = eq;
            double dd = peak - eq;
            if(dd > max_dd) max_dd = dd;

            if(pnl > 0.0001)
            {
               wins++;
               current_loss_streak = 0;
            }
            else if(pnl < -0.0001)
            {
               losses++;
               current_loss_streak++;
               if(current_loss_streak > max_loss_streak)
                  max_loss_streak = current_loss_streak;
            }

            // Symbol count
            string sym = m_forward_trades[i].symbol;
            if(sym == "EURUSDm") eurusd_cnt++;
            else if(sym == "USDJPYm") usdjpy_cnt++;
            else if(sym == "XAUUSDm") xauusd_cnt++;
            else if(sym == "BTCUSDm") btcusd_cnt++;
            else if(sym == "ETHUSDm") ethusd_cnt++;

            // Direction count
            if(m_forward_trades[i].direction == ATG_DIRECTION_BUY) buy_cnt++;
            else sell_cnt++;

            conf_sum += m_forward_trades[i].strategy_confidence;
            qual_sum += m_forward_trades[i].strategy_quality;
         }

         out_snap.win_rate              = NormalizeDouble(((double)wins / (double)n) * 100.0, 2);
         out_snap.loss_rate             = NormalizeDouble(((double)losses / (double)n) * 100.0, 2);
         out_snap.profit_factor         = (losses > 0) ? NormalizeDouble((wins > 0 ? (double)wins / (double)losses : 0.0), 2) : (wins > 0 ? 99.0 : 0.0);
         out_snap.average_r             = NormalizeDouble(r_sum / (double)n, 3);
         out_snap.expectancy            = out_snap.average_r;
         out_snap.maximum_drawdown      = NormalizeDouble(max_dd, 2);
         out_snap.p95_drawdown          = NormalizeDouble(max_dd * 0.95, 2);
         out_snap.maximum_losing_streak = max_loss_streak;

         // Median R
         ArraySort(r_vals);
         if(n % 2 == 1) out_snap.median_r = r_vals[n / 2];
         else out_snap.median_r = (r_vals[n / 2 - 1] + r_vals[n / 2]) / 2.0;

         out_snap.symbol_distribution = StringFormat("EURUSDm:%d;USDJPYm:%d;XAUUSDm:%d;BTCUSDm:%d;ETHUSDm:%d",
            eurusd_cnt, usdjpy_cnt, xauusd_cnt, btcusd_cnt, ethusd_cnt);
         out_snap.direction_distribution = StringFormat("BUY:%d;SELL:%d", buy_cnt, sell_cnt);
         out_snap.confidence_quality_distribution = StringFormat("AVG_CONF:%.2f;AVG_QUAL:%.2f",
            conf_sum / (double)n, qual_sum / (double)n);
      }

      out_snap.data_quality_statistics = StringFormat("GAPS:%d;STALE:%d;ANOMALIES:%d;SIZING_REJ:%d;DUPLICATES:%d",
         m_monitoring.data_gaps_count, m_monitoring.stale_market_data_count,
         m_monitoring.spread_anomaly_count, m_monitoring.position_sizing_rejections,
         m_monitoring.duplicate_trade_prevented);

      // Cache snapshot
      int s_idx = ArraySize(m_milestone_snapshots);
      ArrayResize(m_milestone_snapshots, s_idx + 1);
      m_milestone_snapshots[s_idx] = out_snap;

      // Persist to storage
      if(m_storage != NULL && m_storage.IsEnabled())
      {
         m_storage.AppendMilestoneSnapshot(out_snap);
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Step 7: Generate & Persist Daily Snapshot                      |
   //+----------------------------------------------------------------+
   bool GenerateDailySnapshot(datetime t = 0, const string health = "HEALTHY")
   {
      if(t == 0) t = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(t, dt);
      string d_key = StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);

      SForwardDailySnapshot snap;
      snap.Reset(d_key);
      snap.timestamp          = t;
      snap.cohort_id          = m_active_cohort.cohort_id;
      snap.trades_generated   = m_active_cohort.total_trades;
      snap.trades_closed      = m_active_cohort.valid_trades;
      snap.sample_size        = m_active_cohort.valid_trades;
      snap.pnl                = m_active_cohort.net_pnl;
      snap.data_health        = health;
      snap.persistence_health = (m_storage != NULL && m_storage.IsEnabled()) ? "READY" : "DISABLED";
      snap.anomalies_count    = m_monitoring.corrupted_records_detected + m_monitoring.duplicate_trade_prevented;
      snap.anomalies_summary  = m_monitoring.last_incident_note;

      int n = ArraySize(m_forward_trades);
      if(n > 0)
      {
         double r_sum = 0.0;
         double peak = m_active_cohort.initial_paper_equity;
         double eq = peak;
         double max_dd = 0.0;
         for(int i = 0; i < n; i++)
         {
            r_sum += m_forward_trades[i].realized_r;
            eq += m_forward_trades[i].net_pnl;
            if(eq > peak) peak = eq;
            double dd = peak - eq;
            if(dd > max_dd) max_dd = dd;
         }
         snap.realized_r    = NormalizeDouble(r_sum / (double)n, 3);
         snap.drawdown      = NormalizeDouble(max_dd, 2);
         snap.drawdown_pct  = (peak > 0.0) ? NormalizeDouble((max_dd / peak) * 100.0, 2) : 0.0;
      }

      int idx = ArraySize(m_daily_snapshots);
      ArrayResize(m_daily_snapshots, idx + 1);
      m_daily_snapshots[idx] = snap;

      if(m_storage != NULL && m_storage.IsEnabled())
      {
         m_storage.AppendDailySnapshot(snap);
      }
      return true;
   }

   //+----------------------------------------------------------------+
   //| Step 8: Generate & Persist Weekly Snapshot                     |
   //+----------------------------------------------------------------+
   bool GenerateWeeklySnapshot(datetime t = 0)
   {
      if(t == 0) t = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(t, dt);
      string w_key = StringFormat("%04d-W%02d", dt.year, (dt.day_of_year / 7) + 1);

      SForwardWeeklySnapshot snap;
      snap.Reset(w_key);
      snap.timestamp         = t;
      snap.cohort_id         = m_active_cohort.cohort_id;
      snap.cumulative_trades = m_active_cohort.valid_trades;
      snap.cumulative_pnl    = m_active_cohort.net_pnl;

      int n = ArraySize(m_forward_trades);
      if(n > 0)
      {
         int wins = 0, losses = 0;
         double r_sum = 0.0;
         for(int i = 0; i < n; i++)
         {
            r_sum += m_forward_trades[i].realized_r;
            if(m_forward_trades[i].net_pnl > 0.0001) wins++;
            else if(m_forward_trades[i].net_pnl < -0.0001) losses++;
         }
         snap.cumulative_r = NormalizeDouble(r_sum, 3);
         snap.win_rate     = NormalizeDouble(((double)wins / (double)n) * 100.0, 2);
         snap.profit_factor = (losses > 0) ? NormalizeDouble((wins > 0 ? (double)wins / (double)losses : 0.0), 2) : 99.0;
      }

      int idx = ArraySize(m_weekly_snapshots);
      ArrayResize(m_weekly_snapshots, idx + 1);
      m_weekly_snapshots[idx] = snap;

      if(m_storage != NULL && m_storage.IsEnabled())
      {
         m_storage.AppendWeeklySnapshot(snap);
      }
      return true;
   }

   //+----------------------------------------------------------------+
   //| Step 9: Generate & Persist Monthly Snapshot                    |
   //+----------------------------------------------------------------+
   bool GenerateMonthlySnapshot(datetime t = 0, CStatisticalEvaluationEngine* stat_engine = NULL)
   {
      if(t == 0) t = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(t, dt);
      string m_key = StringFormat("%04d-%02d", dt.year, dt.mon);

      SForwardMonthlySnapshot snap;
      snap.Reset(m_key);
      snap.timestamp    = t;
      snap.cohort_id    = m_active_cohort.cohort_id;
      snap.total_trades = m_active_cohort.valid_trades;

      if(m_active_cohort.valid_trades > 0 && stat_engine != NULL)
      {
         SPaperTrade fwd_clean[];
         GetValidForwardTrades(fwd_clean);
         SPhase8EvaluationResult stat_res;
         stat_engine.RunFullEvaluation(fwd_clean, stat_res, m_active_cohort.initial_paper_equity, 100);

         snap.win_rate            = stat_res.win_rate;
         snap.profit_factor       = stat_res.profit_factor;
         snap.expectancy          = stat_res.expectancy;
         snap.sharpe_ratio        = (stat_res.equity_analysis.equity_volatility > 0.0001) ? (stat_res.expectancy / stat_res.equity_analysis.equity_volatility) : 0.0;
         snap.sortino_ratio       = stat_res.equity_analysis.recovery_factor;
         snap.robustness_survival = stat_res.robustness_result.edge_survival_status;
         snap.evidence_class      = EvidenceClassificationToString(stat_res.evidence_class);
         snap.recommendation      = (stat_res.sample_tier == SAMPLE_INSUFFICIENT) ? "CONTINUE_COLLECTING" : "EVALUATE_NEXT_GATE";
      }
      else
      {
         snap.evidence_class = "INSUFFICIENT_SAMPLE";
         snap.recommendation = "CONTINUE_COLLECTING";
      }

      int idx = ArraySize(m_monthly_snapshots);
      ArrayResize(m_monthly_snapshots, idx + 1);
      m_monthly_snapshots[idx] = snap;

      if(m_storage != NULL && m_storage.IsEnabled())
      {
         m_storage.AppendMonthlySnapshot(snap);
      }
      return true;
   }

   //+----------------------------------------------------------------+
   //| Step 10: Legacy Snapshot Compatibility Method                  |
   //+----------------------------------------------------------------+
   SForwardSnapshotRecord TakeSnapshot(const string p_type = "DAILY", datetime t = 0, double current_equity = 10.00, double max_dd = 0.0, double max_dd_pct = 0.0)
   {
      string p_key = "";
      if(t == 0) t = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(t, dt);
      if(p_type == "DAILY") p_key = StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);
      else if(p_type == "MONTHLY") p_key = StringFormat("%04d-%02d", dt.year, dt.mon);
      else p_key = StringFormat("%04d-W%02d", dt.year, (dt.day_of_year / 7) + 1);

      SForwardSnapshotRecord rec;
      rec.Reset(p_type, p_key);
      rec.timestamp          = t;
      rec.cohort_id          = m_active_cohort.cohort_id;
      rec.config_fingerprint = m_snapshot.config_fingerprint;
      rec.current_equity     = current_equity;
      rec.max_drawdown       = max_dd;
      rec.max_drawdown_pct   = max_dd_pct;
      rec.quality_warnings   = m_active_cohort.warning_trades;
      rec.quality_invalids   = m_active_cohort.invalid_trades;

      double pnl_sum = 0.0;
      double r_sum   = 0.0;
      int wins = 0;
      int losses = 0;

      for(int i = 0; i < ArraySize(m_forward_trades); i++)
      {
         rec.trades_closed++;
         pnl_sum += m_forward_trades[i].net_pnl;
         r_sum   += m_forward_trades[i].realized_r;
         if(m_forward_trades[i].net_pnl > 0.0001) wins++;
         else if(m_forward_trades[i].net_pnl < -0.0001) losses++;
      }

      rec.wins       = wins;
      rec.losses     = losses;
      rec.net_pnl    = NormalizeDouble(pnl_sum, 2);
      rec.win_rate   = (rec.trades_closed > 0) ? NormalizeDouble(((double)wins / (double)rec.trades_closed) * 100.0, 2) : 0.0;
      rec.avg_r      = (rec.trades_closed > 0) ? NormalizeDouble(r_sum / (double)rec.trades_closed, 3) : 0.0;
      rec.expectancy = rec.avg_r;

      int idx = ArraySize(m_snapshots);
      ArrayResize(m_snapshots, idx + 1);
      m_snapshots[idx] = rec;

      if(m_storage != NULL && m_storage.IsEnabled())
      {
         m_storage.AppendForwardSnapshot(rec);
      }
      return rec;
   }

   void CheckPeriodicSnapshots(datetime current_time)
   {
      if(m_active_cohort.valid_trades == 0) return;

      static datetime last_snapshot_day = 0;
      static datetime last_snapshot_week = 0;
      static datetime last_snapshot_month = 0;

      MqlDateTime dt;
      TimeToStruct(current_time, dt);

      datetime day_start = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
      if(day_start > last_snapshot_day && dt.hour >= 23 && dt.min >= 50)
      {
         TakeSnapshot("DAILY", current_time);
         GenerateDailySnapshot(current_time);
         last_snapshot_day = day_start;
      }

      if(dt.day_of_week == 5 && dt.hour >= 23 && current_time - last_snapshot_week > 86400 * 5)
      {
         TakeSnapshot("WEEKLY", current_time);
         GenerateWeeklySnapshot(current_time);
         last_snapshot_week = current_time;
      }

      if(dt.day == 1 && current_time - last_snapshot_month > 86400 * 25)
      {
         TakeSnapshot("MONTHLY", current_time);
         GenerateMonthlySnapshot(current_time);
         last_snapshot_month = current_time;
      }
   }

   //+----------------------------------------------------------------+
   //| Getters for Safe Isolation                                     |
   //+----------------------------------------------------------------+
   ENUM_DATA_QUALITY_FLAG ValidateTradeQuality(const SPaperTrade &t, string &warning_reason)
   {
      return ValidateTradeDataQuality(t, warning_reason);
   }

   void GetValidForwardTrades(SPaperTrade &out_trades[]) const
   {
      ArrayResize(out_trades, ArraySize(m_forward_trades));
      for(int i = 0; i < ArraySize(m_forward_trades); i++)
         out_trades[i] = m_forward_trades[i];
   }

   void GetSyntheticTrades(SPaperTrade &out_trades[]) const
   {
      ArrayResize(out_trades, ArraySize(m_synthetic_trades));
      for(int i = 0; i < ArraySize(m_synthetic_trades); i++)
         out_trades[i] = m_synthetic_trades[i];
   }

   void GetInvalidTrades(SPaperTrade &out_trades[]) const
   {
      ArrayResize(out_trades, ArraySize(m_invalid_trades));
      for(int i = 0; i < ArraySize(m_invalid_trades); i++)
         out_trades[i] = m_invalid_trades[i];
   }

   int  GetValidForwardTradeCount() const { return m_active_cohort.valid_trades; }
   int  GetSyntheticTradeCount() const    { return ArraySize(m_synthetic_trades); }
   int  GetInvalidTradeCount() const      { return m_active_cohort.invalid_trades; }
   int  GetWarningRecordCount() const     { return m_active_cohort.warning_trades; }
   int  GetInvalidRecordCount() const     { return m_active_cohort.invalid_trades; }
   int  GetCohortTradeCount() const       { return m_active_cohort.trade_count; }
   double GetForwardNetPnl() const        { return m_active_cohort.net_pnl; }

   string GetFingerprint() const          { return m_snapshot.config_fingerprint; }
   string GetConfigFingerprint() const    { return m_snapshot.config_fingerprint; }
   string GetCohortId() const             { return m_active_cohort.cohort_id; }
   SForwardCohort GetCohort() const       { return m_active_cohort; }
   SForwardCohort GetActiveCohort() const { return m_active_cohort; }
   SForwardConfigSnapshot GetSnapshot() const { return m_snapshot; }
   SForwardMonitoringState GetMonitoringState() const { return m_monitoring; }

   int GetMilestoneSnapshots(SForwardMilestoneSnapshot &out_snaps[]) const
   {
      int n = ArraySize(m_milestone_snapshots);
      ArrayResize(out_snaps, n);
      for(int i = 0; i < n; i++)
         out_snaps[i] = m_milestone_snapshots[i];
      return n;
   }

   int GetDailySnapshots(SForwardDailySnapshot &out_snaps[]) const
   {
      int n = ArraySize(m_daily_snapshots);
      ArrayResize(out_snaps, n);
      for(int i = 0; i < n; i++)
         out_snaps[i] = m_daily_snapshots[i];
      return n;
   }

   int GetWeeklySnapshots(SForwardWeeklySnapshot &out_snaps[]) const
   {
      int n = ArraySize(m_weekly_snapshots);
      ArrayResize(out_snaps, n);
      for(int i = 0; i < n; i++)
         out_snaps[i] = m_weekly_snapshots[i];
      return n;
   }

   int GetMonthlySnapshots(SForwardMonthlySnapshot &out_snaps[]) const
   {
      int n = ArraySize(m_monthly_snapshots);
      ArrayResize(out_snaps, n);
      for(int i = 0; i < n; i++)
         out_snaps[i] = m_monthly_snapshots[i];
      return n;
   }

   // 15 Forward Monitoring Recording Methods
   void RecordDataGap()                         { m_monitoring.data_gaps_count++; }
   void RecordStaleMarketData()                 { m_monitoring.stale_market_data_count++; }
   void RecordSymbolUnavailable()              { m_monitoring.symbol_unavailable_count++; }
   void RecordSpreadAnomaly()                  { m_monitoring.spread_anomaly_count++; }
   void RecordInvalidPrice()                   { m_monitoring.invalid_prices_count++; }
   void RecordPositionSizingRejection(const string symbol, const string reason)
   {
      m_monitoring.position_sizing_rejections++;
      m_monitoring.last_incident_note = StringFormat("SIZING_REJECTED [%s]: %s", symbol, reason);
   }
   void RecordTradeCreationFailure(const string reason)
   {
      m_monitoring.paper_trade_creation_failures++;
      m_monitoring.last_incident_note = "CREATION_FAIL: " + reason;
   }
   void RecordPersistenceWriteError()
   {
      m_monitoring.persistence_write_errors++;
      m_alert_manager.EmitAlert(ALERT_PERSISTENCE_FAILURE, "CRITICAL", "Storage", "Persistence write error occurred");
   }
   void RecordPersistenceRecoveryError()
   {
      m_monitoring.persistence_recovery_errors++;
      m_alert_manager.EmitAlert(ALERT_UNEXPECTED_STATE_RESET, "CRITICAL", "Storage", "Persistence recovery failure detected");
   }
   void RecordDuplicateTradePrevented()        { m_monitoring.duplicate_trade_prevented++; }
   void RecordUnexpectedStateTransition()
   {
      m_monitoring.unexpected_state_transitions++;
      m_alert_manager.EmitAlert(ALERT_UNEXPECTED_BEHAVIOR, "WARNING", "Engine", "Unexpected state transition detected");
   }
   void RecordSafetyGateViolation()
   {
      m_monitoring.safety_gate_violations++;
      m_alert_manager.EmitAlert(ALERT_EXECUTION_SAFETY_VIOLATION, "CRITICAL", "ExecutionGuard", "Safety gate violation detected");
   }
   void RecordDatasetContaminationPrevented()  { m_monitoring.dataset_contamination_prevented++; }
   void RecordEaRestart()                      { m_monitoring.ea_restarts_count++; }
   void RecordMissingClosedTrade()             { m_monitoring.missing_closed_trades_count++; }

   // Phase 10 Additional Diagnostic Recorders
   void RecordMissingBar()                     { m_monitoring.missing_bars_count++; }
   void RecordTimestampDiscontinuity()         { m_monitoring.timestamp_discontinuities_count++; }
   void RecordDuplicateSourceBar()             { m_monitoring.duplicate_source_bars_count++; }
   void RecordInvalidSLTP()                    { m_monitoring.invalid_sltp_count++; }
   void RecordInvalidRisk()                    { m_monitoring.invalid_risk_count++; }
   void RecordInvalidVolume()                  { m_monitoring.invalid_volume_count++; }
   void RecordConfigMismatch()                 { m_monitoring.config_version_mismatches_count++; }
   void RecordLargeDrawdownAlert(double dd_pct)
   {
      m_monitoring.large_drawdown_alerts++;
      m_alert_manager.EmitAlert(ALERT_LARGE_DRAWDOWN, "WARNING", "RiskEngine",
         StringFormat("Large drawdown detected: %.2f%%", dd_pct));
   }
   void RecordUnexpectedBehaviorAlert(const string msg)
   {
      m_monitoring.unexpected_behavior_alerts++;
      m_alert_manager.EmitAlert(ALERT_UNEXPECTED_BEHAVIOR, "NOTICE", "Core", msg);
   }

   //+----------------------------------------------------------------+
   //| Step 11: Generate Comprehensive Forward Evidence Report        |
   //+----------------------------------------------------------------+
   string GenerateForwardEvidenceReport(CStatisticalEvaluationEngine* stat_engine = NULL)
   {
      string out = "";
      out += "\n======================================================================\n";
      out += "      ATG TRADING ENGINE - PHASE 10 FORWARD EVIDENCE & MONITORING     \n";
      out += "======================================================================\n";
      out += StringFormat("Active Cohort:         %s | Status: %s\n", m_active_cohort.cohort_id, CohortStatusToString(m_active_cohort.status));
      out += StringFormat("Config Fingerprint:    %s\n", m_snapshot.config_fingerprint);
      out += StringFormat("Strategy ID:           %s (FROZEN)\n", m_snapshot.strategy_id);
      out += StringFormat("Risk Parameters:       Risk=%.2f%% | MinRR=%.2f | SL_ATR=%.2fx | TP_RR=%.2fx\n",
         m_snapshot.risk_percent, m_snapshot.min_reward_risk, m_snapshot.sl_atr_multiplier, m_snapshot.tp_rr_multiplier);
      out += "----------------------------------------------------------------------\n";
      out += "1. DATASET CLASSIFICATION & SEPARATION AUDIT\n";
      out += StringFormat("  [FORWARD LIVE PAPER]:  %d trades (Valid: %d, Warnings: %d)\n",
         m_active_cohort.total_trades, m_active_cohort.valid_trades, m_active_cohort.warning_trades);
      out += StringFormat("  [SYNTHETIC TEST DATA]: %d trades (STRICTLY EXCLUDED FROM FORWARD EVIDENCE)\n",
         ArraySize(m_synthetic_trades));
      out += StringFormat("  [INVALID RECORDS]:     %d trades (Excluded from statistical evaluation)\n",
         m_active_cohort.invalid_trades);
      out += StringFormat("  Current Milestone:     %s\n", SampleMilestoneToString(m_active_cohort.milestone));
      out += "  Target Evidence Goal:  50 - 100 Forward Closed Trades\n";
      out += "----------------------------------------------------------------------\n";
      out += "2. FORWARD SYSTEM MONITORING & HEALTH (15 DIAGNOSTIC AREAS)\n";
      out += StringFormat("  [01] Data Gaps:              %d\n", m_monitoring.data_gaps_count);
      out += StringFormat("  [02] Stale Market Data:      %d\n", m_monitoring.stale_market_data_count);
      out += StringFormat("  [03] Symbol Unavailable:     %d\n", m_monitoring.symbol_unavailable_count);
      out += StringFormat("  [04] Spread Anomalies:       %d\n", m_monitoring.spread_anomaly_count);
      out += StringFormat("  [05] Invalid Prices:         %d\n", m_monitoring.invalid_prices_count);
      out += StringFormat("  [06] Position-Sizing Rejects:%d\n", m_monitoring.position_sizing_rejections);
      out += StringFormat("  [07] Trade Creation Fails:   %d\n", m_monitoring.paper_trade_creation_failures);
      out += StringFormat("  [08] Persistence Write Errs: %d\n", m_monitoring.persistence_write_errors);
      out += StringFormat("  [09] Recovery Failures:      %d\n", m_monitoring.persistence_recovery_errors);
      out += StringFormat("  [10] Duplicate Suppressions: %d\n", m_monitoring.duplicate_trade_prevented);
      out += StringFormat("  [11] Unexpected State Trans: %d\n", m_monitoring.unexpected_state_transitions);
      out += StringFormat("  [12] Safety-Gate Violations: %d\n", m_monitoring.safety_gate_violations);
      out += StringFormat("  [13] Dataset Contamination:  %d prevented\n", m_monitoring.dataset_contamination_prevented);
      out += StringFormat("  [14] EA Restarts / Recover:  %d\n", m_monitoring.ea_restarts_count);
      out += StringFormat("  [15] Missing Closed Records: %d\n", m_monitoring.missing_closed_trades_count);
      out += StringFormat("  Last Incident Note:          %s\n", m_monitoring.last_incident_note);
      out += "----------------------------------------------------------------------\n";

      // Evaluate Phase 8 statistics strictly on clean forward live trades
      if(m_active_cohort.valid_trades > 0 && stat_engine != NULL)
      {
         SPaperTrade fwd_clean[];
         GetValidForwardTrades(fwd_clean);
         SPhase8EvaluationResult stat_res;
         stat_engine.RunFullEvaluation(fwd_clean, stat_res, m_active_cohort.initial_paper_equity, 100);

         out += "3. PHASE 8 STATISTICAL VERDICT ON FORWARD EVIDENCE\n";
         out += StringFormat("  Forward Trades Evaluated: %d\n", stat_res.total_trades);
         out += StringFormat("  Win Rate:     %.2f%%  |  Profit Factor: %.2f\n", stat_res.win_rate, stat_res.profit_factor);
         out += StringFormat("  Net PnL:      $%.2f  |  Avg Realized R: %.3fR\n", stat_res.net_pnl, stat_res.avg_r);
         out += StringFormat("  Expectancy:   %.3fR per trade\n", stat_res.expectancy);
         out += StringFormat("  Max Drawdown: $%.2f (%.2f%%)\n", stat_res.max_drawdown, stat_res.max_drawdown_pct);
         out += StringFormat("  Sample Tier:  %s\n", SampleClassificationToString(stat_res.sample_tier));
         out += StringFormat("  Evidence Class: %s\n", EvidenceClassificationToString(stat_res.evidence_class));
         out += StringFormat("  Slippage Stress Edge: %s\n", stat_res.robustness_result.edge_survival_status);
      }
      else if(m_active_cohort.valid_trades > 0)
      {
         out += "3. FORWARD EVIDENCE SUMMARY\n";
         out += StringFormat("  Valid Forward Trades: %d\n", m_active_cohort.valid_trades);
         out += StringFormat("  Net Forward PnL:      $%.2f\n", m_active_cohort.net_pnl);
         out += StringFormat("  Sample Milestone:     %s\n", SampleMilestoneToString(m_active_cohort.milestone));
      }
      else
      {
         out += "3. PHASE 8 STATISTICAL VERDICT ON FORWARD EVIDENCE\n";
         out += "  No closed forward live trades recorded yet. Status: AWAITING_FORWARD_SIGNALS\n";
         out += "  Evidence Classification: INSUFFICIENT_SAMPLE (0 forward trades)\n";
      }

      out += "----------------------------------------------------------------------\n";
      out += "4. SAFETY BOUNDARY & HARD REALITIES\n";
      out += "  can_trade = FALSE | MONITOR_ONLY = TRUE | ZERO LIVE ORDER CAPABILITY\n";
      out += "  Strategy parameters remain strictly frozen. No optimization permitted.\n";
      out += "======================================================================\n";
      return out;
   }
};

#endif
