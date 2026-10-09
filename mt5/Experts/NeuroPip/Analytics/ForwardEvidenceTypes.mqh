//+------------------------------------------------------------------+
//| ForwardEvidenceTypes.mqh                                         |
//| NeuroPip - Phase 9                                     |
//| Forward Paper Validation, Evidence Cohorts & Monitoring Types    |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_FORWARD_EVIDENCE_TYPES_MQH
#define ATG_FORWARD_EVIDENCE_TYPES_MQH

#include "../Execution/TradeTypes.mqh"
#include "../Intelligence/MarketRegimeTypes.mqh"
#include "../Config/Config.mqh"

//+------------------------------------------------------------------+
//| Dataset Classification                                           |
//| Guarantees separation of real forward paper data from synthetic  |
//+------------------------------------------------------------------+
enum ENUM_DATASET_CLASS
{
   DATASET_FORWARD_LIVE_PAPER = 0, // Real-time forward paper trading from live feeds
   DATASET_SYNTHETIC_TEST     = 1, // Unit/regression test fixtures and dry-runs
   DATASET_HISTORICAL_IMPORTED = 2,// Offline backfill / historical replay
   DATASET_UNKNOWN            = 3  // Unclassified / legacy records
};

inline string DatasetClassToString(ENUM_DATASET_CLASS cls)
{
   switch(cls)
   {
      case DATASET_FORWARD_LIVE_PAPER:  return "FORWARD_LIVE_PAPER";
      case DATASET_SYNTHETIC_TEST:      return "SYNTHETIC_TEST";
      case DATASET_HISTORICAL_IMPORTED: return "HISTORICAL_IMPORTED";
      case DATASET_UNKNOWN:             return "DATASET_UNKNOWN";
   }
   return "UNKNOWN";
}

inline ENUM_DATASET_CLASS StringToDatasetClass(const string str)
{
   if(str == "FORWARD_LIVE_PAPER") return DATASET_FORWARD_LIVE_PAPER;
   if(str == "SYNTHETIC_TEST") return DATASET_SYNTHETIC_TEST;
   if(str == "HISTORICAL_IMPORTED") return DATASET_HISTORICAL_IMPORTED;
   return DATASET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Data Quality Classification Flag                                 |
//+------------------------------------------------------------------+
enum ENUM_DATA_QUALITY_FLAG
{
   DATA_QUALITY_VALID = 0,   // All invariants strictly satisfied
   DATA_QUALITY_WARNING = 1, // Non-fatal condition (e.g. elevated spread, minor data gap)
   DATA_QUALITY_INVALID = 2  // Fatal defect (corrupted record, inverted timestamps, zero risk)
};

inline string DataQualityToString(ENUM_DATA_QUALITY_FLAG flag)
{
   switch(flag)
   {
      case DATA_QUALITY_VALID:   return "DATA_VALID";
      case DATA_QUALITY_WARNING: return "DATA_WARNING";
      case DATA_QUALITY_INVALID: return "DATA_INVALID";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Forward Sample Milestones                                        |
//+------------------------------------------------------------------+
enum ENUM_SAMPLE_MILESTONE
{
   MILESTONE_0_TRADES = 0,                // 0 - 9 trades
   MILESTONE_10_TRADES,                   // 10 - 14 trades
   MILESTONE_15_TRADES,                   // 15 - 24 trades
   MILESTONE_25_TRADES,                   // 25 - 29 trades
   MILESTONE_30_TRADES,                   // 30 - 49 trades
   MILESTONE_50_TRADES,                   // 50 - 74 trades (Target cohort boundary)
   MILESTONE_75_TRADES,                   // 75 - 99 trades
   MILESTONE_100_TRADES                   // 100+ trades
};

inline string SampleMilestoneToString(ENUM_SAMPLE_MILESTONE ms)
{
   switch(ms)
   {
      case MILESTONE_0_TRADES:              return "MILESTONE_0 (0-9 trades)";
      case MILESTONE_10_TRADES:             return "MILESTONE_10 (10-14 trades)";
      case MILESTONE_15_TRADES:             return "MILESTONE_15 (15-24 trades)";
      case MILESTONE_25_TRADES:             return "MILESTONE_25 (25-29 trades)";
      case MILESTONE_30_TRADES:             return "MILESTONE_30 (30-49 trades)";
      case MILESTONE_50_TRADES:             return "MILESTONE_50 (50-74 trades)";
      case MILESTONE_75_TRADES:             return "MILESTONE_75 (75-99 trades)";
      case MILESTONE_100_TRADES:            return "MILESTONE_100 (100+ trades)";
   }
   return "UNKNOWN";
}

inline ENUM_SAMPLE_MILESTONE GetSampleMilestone(int valid_trades)
{
   if(valid_trades < 10)  return MILESTONE_0_TRADES;
   if(valid_trades < 15)  return MILESTONE_10_TRADES;
   if(valid_trades < 25)  return MILESTONE_15_TRADES;
   if(valid_trades < 30)  return MILESTONE_25_TRADES;
   if(valid_trades < 50)  return MILESTONE_30_TRADES;
   if(valid_trades < 75)  return MILESTONE_50_TRADES;
   if(valid_trades < 100) return MILESTONE_75_TRADES;
   return MILESTONE_100_TRADES;
}

//+------------------------------------------------------------------+
//| Evidence Cohort Status                                           |
//+------------------------------------------------------------------+
enum ENUM_COHORT_STATUS
{
   COHORT_STATUS_COLLECTING = 0,
   COHORT_STATUS_MILESTONE_10,
   COHORT_STATUS_MILESTONE_15,
   COHORT_STATUS_MILESTONE_25,
   COHORT_STATUS_MILESTONE_30,
   COHORT_STATUS_MILESTONE_50,
   COHORT_STATUS_MILESTONE_75,
   COHORT_STATUS_MILESTONE_100,
   COHORT_STATUS_PAUSED,
   COHORT_STATUS_INVALIDATED,
   COHORT_STATUS_COMPLETED
};

inline string CohortStatusToString(ENUM_COHORT_STATUS status)
{
   switch(status)
   {
      case COHORT_STATUS_COLLECTING:     return "COLLECTING";
      case COHORT_STATUS_MILESTONE_10:   return "MILESTONE_10";
      case COHORT_STATUS_MILESTONE_15:   return "MILESTONE_15";
      case COHORT_STATUS_MILESTONE_25:   return "MILESTONE_25";
      case COHORT_STATUS_MILESTONE_30:   return "MILESTONE_30";
      case COHORT_STATUS_MILESTONE_50:   return "MILESTONE_50";
      case COHORT_STATUS_MILESTONE_75:   return "MILESTONE_75";
      case COHORT_STATUS_MILESTONE_100:  return "MILESTONE_100";
      case COHORT_STATUS_PAUSED:         return "PAUSED";
      case COHORT_STATUS_INVALIDATED:    return "INVALIDATED";
      case COHORT_STATUS_COMPLETED:      return "COMPLETED";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Frozen Forward Configuration Snapshot                            |
//| Enforces parameter freeze across the evidence collection window  |
//+------------------------------------------------------------------+
struct SForwardConfigSnapshot
{
   string   snapshot_id;
   string   ea_version;
   string   config_version;
   string   strategy_id;
   double   risk_percent;
   double   min_reward_risk;
   double   sl_atr_multiplier;
   double   tp_rr_multiplier;
   double   confidence_threshold;
   double   confluence_threshold;
   string   timeframe_hierarchy;
   int      spread_threshold_points;
   double   entry_buffer_points;
   int      plan_expiry_sec;
   datetime snapshot_time;
   string   config_fingerprint; // Deterministic hash/fingerprint

   void Reset()
   {
      snapshot_id             = "";
      ea_version              = "0.9.0";
      config_version          = "2.0.0";
      strategy_id             = "NEUROPIP_TREND_CONTINUATION";
      risk_percent            = 1.0;
      min_reward_risk         = 1.5;
      sl_atr_multiplier       = 2.0;
      tp_rr_multiplier        = 2.0;
      confidence_threshold    = 0.70;
      confluence_threshold    = 0.65;
      timeframe_hierarchy     = "M1|M5|M15|H1|H4|D1";
      spread_threshold_points = 40;
      entry_buffer_points     = 0.0;
      plan_expiry_sec         = 1800;
      snapshot_time           = 0;
      config_fingerprint      = "";
   }

   void Capture(const CConfig &cfg, const string cohort_id = "COHORT_01")
   {
      Reset();
      snapshot_id             = cohort_id + "_SNAP";
      ea_version              = cfg.ea_version;
      config_version          = cfg.config_version;
      strategy_id             = (cfg.active_strategy_id != "") ? cfg.active_strategy_id : "NEUROPIP_TREND_CONTINUATION";
      risk_percent            = cfg.risk_percent;
      min_reward_risk         = cfg.min_reward_risk;
      sl_atr_multiplier       = cfg.sl_atr_multiplier;
      tp_rr_multiplier        = cfg.tp_rr_multiplier;
      confidence_threshold    = 0.70;
      confluence_threshold    = 0.65;
      spread_threshold_points = cfg.max_spread_tolerance;
      entry_buffer_points     = cfg.entry_buffer_points;
      plan_expiry_sec         = cfg.plan_expiry_sec;
      snapshot_time           = TimeCurrent();
      BuildFingerprint();
   }

   bool VerifyConfig(const CConfig &cfg) const
   {
      if(cfg.ea_version != ea_version) return false;
      if(MathAbs(cfg.risk_percent - risk_percent) > 0.001) return false;
      if(MathAbs(cfg.min_reward_risk - min_reward_risk) > 0.001) return false;
      if(MathAbs(cfg.sl_atr_multiplier - sl_atr_multiplier) > 0.001) return false;
      if(MathAbs(cfg.tp_rr_multiplier - tp_rr_multiplier) > 0.001) return false;
      if(cfg.max_spread_tolerance != spread_threshold_points) return false;
      return true;
   }

   string BuildFingerprint()
   {
      string strat_key = (strategy_id == "NEUROPIP_MOMENTUM_BREAKOUT") ? "NEUROPIP_MOMENTUM_BREAKOUT" : "ATG_TREND_CONTINUATION";
      // Deterministic frozen specification fingerprint (FP-B741A5209E579706)
      string raw = StringFormat("ATG|EA:%s|CFG:%s|STRAT:%s|R:%.2f|RR:%.2f|SL:%.2f|TP:%.2f|CONF:%.2f|CONF_MIN:%.2f|TFS:%s|SPD:%d",
         ea_version, config_version, strat_key, risk_percent, min_reward_risk,
         sl_atr_multiplier, tp_rr_multiplier, confidence_threshold, confluence_threshold,
         timeframe_hierarchy, spread_threshold_points);

      // Compute deterministic 64-bit FNV-1a hash
      ulong hash = 14695981039346656037U;
      int len = StringLen(raw);
      for(int i = 0; i < len; i++)
      {
         hash ^= (uchar)StringGetCharacter(raw, i);
         hash *= 1099511628211U;
      }
      config_fingerprint = StringFormat("FP-%016I64X", hash);
      return config_fingerprint;
   }
};

//+------------------------------------------------------------------+
//| Forward Evidence Cohort Metadata Record                          |
//+------------------------------------------------------------------+
struct SForwardCohort
{
   string                  cohort_id;
   datetime                start_time;
   datetime                end_time;
   string                  strategy_version;
   string                  config_version;
   string                  config_fingerprint;
   string                  symbol_universe;
   ENUM_DATASET_CLASS      dataset_class;
   double                  initial_paper_equity;
   int                     total_trades;
   int                     valid_trades;
   int                     warning_trades;
   int                     invalid_trades;
   int                     trade_count;
   double                  net_pnl;
   ENUM_COHORT_STATUS      status;
   ENUM_SAMPLE_MILESTONE   milestone;

   void Reset(const string id = "COHORT_01")
   {
      cohort_id            = id;
      start_time           = 0;
      end_time             = 0;
      strategy_version     = "0.9.0";
      config_version       = "2.0.0";
      config_fingerprint   = "";
      symbol_universe      = "EURUSDm|USDJPYm|XAUUSDm|BTCUSDm|ETHUSDm";
      dataset_class        = DATASET_FORWARD_LIVE_PAPER;
      initial_paper_equity = 10.00;
      total_trades         = 0;
      valid_trades         = 0;
      warning_trades       = 0;
      invalid_trades       = 0;
      trade_count          = 0;
      net_pnl              = 0.0;
      status               = COHORT_STATUS_COLLECTING;
      milestone            = MILESTONE_0_TRADES;
   }

   void UpdateMilestone()
   {
      if(valid_trades < 10)
      {
         milestone = MILESTONE_0_TRADES;
         status    = COHORT_STATUS_COLLECTING;
      }
      else if(valid_trades < 15)
      {
         milestone = MILESTONE_10_TRADES;
         status    = COHORT_STATUS_MILESTONE_10;
      }
      else if(valid_trades < 25)
      {
         milestone = MILESTONE_15_TRADES;
         status    = COHORT_STATUS_MILESTONE_15;
      }
      else if(valid_trades < 30)
      {
         milestone = MILESTONE_25_TRADES;
         status    = COHORT_STATUS_MILESTONE_25;
      }
      else if(valid_trades < 50)
      {
         milestone = MILESTONE_30_TRADES;
         status    = COHORT_STATUS_MILESTONE_30;
      }
      else if(valid_trades < 75)
      {
         milestone = MILESTONE_50_TRADES;
         status    = COHORT_STATUS_MILESTONE_50;
      }
      else if(valid_trades < 100)
      {
         milestone = MILESTONE_75_TRADES;
         status    = COHORT_STATUS_MILESTONE_75;
      }
      else
      {
         milestone = MILESTONE_100_TRADES;
         status    = COHORT_STATUS_MILESTONE_100;
      }
   }
};

//+------------------------------------------------------------------+
//| Forward Monitoring Health State                                  |
//| Explicit tracking across 15 monitoring areas & Phase 10 metrics   |
//+------------------------------------------------------------------+
struct SForwardMonitoringState
{
   datetime last_check_time;
   bool     market_data_healthy;

   // 1. Data gaps
   int      data_gaps_count;
   // 2. Stale market data
   int      stale_market_data_count;
   // 3. Symbol unavailable
   int      symbol_unavailable_count;
   // 4. Spread anomalies
   int      spread_anomaly_count;
   // 5. Invalid prices
   int      invalid_prices_count;
   // 6. Position-sizing rejection
   int      position_sizing_rejections;
   // 7. Paper-trade creation failure
   int      paper_trade_creation_failures;
   // 8. Paper-trade persistence failure
   int      persistence_write_errors;
   // 9. Recovery failure
   int      persistence_recovery_errors;
   // 10. Duplicate trade
   int      duplicate_trade_prevented;
   // 11. Unexpected state transitions
   int      unexpected_state_transitions;
   // 12. Safety-gate violations
   int      safety_gate_violations;
   // 13. Forward/test dataset contamination
   int      dataset_contamination_prevented;
   // 14. EA restart/recovery
   int      ea_restarts_count;
   // 15. Missing closed-trade records
   int      missing_closed_trades_count;

   // Phase 10 Data Quality Diagnostic Fields
   int      missing_bars_count;
   int      timestamp_discontinuities_count;
   int      duplicate_source_bars_count;
   int      invalid_sltp_count;
   int      invalid_risk_count;
   int      invalid_volume_count;
   int      config_version_mismatches_count;
   int      large_drawdown_alerts;
   int      unexpected_behavior_alerts;

   // Integrity diagnostics
   int      corrupted_records_detected;
   int      chronological_order_violations;
   string   last_incident_note;

   void Reset()
   {
      last_check_time                 = 0;
      market_data_healthy             = true;
      data_gaps_count                 = 0;
      stale_market_data_count         = 0;
      symbol_unavailable_count        = 0;
      spread_anomaly_count            = 0;
      invalid_prices_count            = 0;
      position_sizing_rejections      = 0;
      paper_trade_creation_failures   = 0;
      persistence_write_errors        = 0;
      persistence_recovery_errors     = 0;
      duplicate_trade_prevented       = 0;
      unexpected_state_transitions    = 0;
      safety_gate_violations          = 0;
      dataset_contamination_prevented = 0;
      ea_restarts_count               = 0;
      missing_closed_trades_count     = 0;
      missing_bars_count              = 0;
      timestamp_discontinuities_count = 0;
      duplicate_source_bars_count     = 0;
      invalid_sltp_count              = 0;
      invalid_risk_count              = 0;
      invalid_volume_count            = 0;
      config_version_mismatches_count = 0;
      large_drawdown_alerts           = 0;
      unexpected_behavior_alerts      = 0;
      corrupted_records_detected      = 0;
      chronological_order_violations  = 0;
      last_incident_note              = "NONE";
   }
};

//+------------------------------------------------------------------+
//| Phase 10 Forward Monitoring Alert Types                          |
//+------------------------------------------------------------------+
enum ENUM_FORWARD_ALERT_TYPE
{
   ALERT_PERSISTENCE_FAILURE = 0,
   ALERT_DATA_FEED_FAILURE,
   ALERT_UNEXPECTED_STATE_RESET,
   ALERT_CORRUPT_FORWARD_RECORD,
   ALERT_RISK_CONTRACT_VIOLATION,
   ALERT_CONFIG_MISMATCH,
   ALERT_EXECUTION_SAFETY_VIOLATION,
   ALERT_LARGE_DRAWDOWN,
   ALERT_UNEXPECTED_BEHAVIOR
};

inline string ForwardAlertTypeToString(ENUM_FORWARD_ALERT_TYPE type)
{
   switch(type)
   {
      case ALERT_PERSISTENCE_FAILURE:        return "PERSISTENCE_FAILURE";
      case ALERT_DATA_FEED_FAILURE:          return "DATA_FEED_FAILURE";
      case ALERT_UNEXPECTED_STATE_RESET:     return "UNEXPECTED_STATE_RESET";
      case ALERT_CORRUPT_FORWARD_RECORD:     return "CORRUPT_FORWARD_RECORD";
      case ALERT_RISK_CONTRACT_VIOLATION:    return "RISK_CONTRACT_VIOLATION";
      case ALERT_CONFIG_MISMATCH:            return "CONFIG_MISMATCH";
      case ALERT_EXECUTION_SAFETY_VIOLATION: return "EXECUTION_SAFETY_VIOLATION";
      case ALERT_LARGE_DRAWDOWN:             return "LARGE_DRAWDOWN";
      case ALERT_UNEXPECTED_BEHAVIOR:        return "UNEXPECTED_BEHAVIOR";
   }
   return "UNKNOWN_ALERT";
}

struct SForwardAlertRecord
{
   datetime                timestamp;
   ENUM_FORWARD_ALERT_TYPE alert_type;
   string                  severity;      // "CRITICAL", "WARNING", "NOTICE"
   string                  source;        // Component emitting alert
   string                  message;       // Detail of anomaly
   string                  action_taken;  // "FLAGGED_ONLY", "QUARANTINED", "PERSISTED"
   string                  cohort_id;

   void Reset()
   {
      timestamp    = 0;
      alert_type   = ALERT_UNEXPECTED_BEHAVIOR;
      severity     = "NOTICE";
      source       = "Core";
      message      = "";
      action_taken = "FLAGGED_ONLY";
      cohort_id    = "COHORT_01";
   }
};

//+------------------------------------------------------------------+
//| Comprehensive Phase 10 Milestone Snapshot Record                 |
//| Exported at N = 0, 15, 30, 50, 75, 100                           |
//+------------------------------------------------------------------+
#define FORWARD_MILESTONE_SNAPSHOTS_HEADER "milestone_name,milestone_target,timestamp,cohort_id,config_fingerprint,sample_size,valid_records,invalid_records,warning_records,win_rate,loss_rate,profit_factor,expectancy,average_r,median_r,maximum_drawdown,p95_drawdown,maximum_losing_streak,symbol_distribution,direction_distribution,regime_distribution,confidence_quality_distribution,temporal_distribution,data_quality_statistics"

struct SForwardMilestoneSnapshot
{
   string   milestone_name;         // "N=0", "N=15", "N=30", "N=50", "N=75", "N=100"
   int      milestone_target;       // 0, 15, 30, 50, 75, 100
   datetime timestamp;
   string   cohort_id;
   string   config_fingerprint;

   int      sample_size;
   int      valid_records;
   int      invalid_records;
   int      warning_records;

   double   win_rate;
   double   loss_rate;
   double   profit_factor;
   double   expectancy;
   double   average_r;
   double   median_r;

   double   maximum_drawdown;
   double   p95_drawdown;
   int      maximum_losing_streak;

   // Distributions (semicolon-delimited key:val pairs)
   string   symbol_distribution;
   string   direction_distribution;
   string   regime_distribution;
   string   confidence_quality_distribution;
   string   temporal_distribution;
   string   data_quality_statistics;

   void Reset(const string m_name = "N=0", int target = 0)
   {
      milestone_name                   = m_name;
      milestone_target                 = target;
      timestamp                        = 0;
      cohort_id                        = "COHORT_01";
      config_fingerprint               = "";
      sample_size                      = 0;
      valid_records                    = 0;
      invalid_records                  = 0;
      warning_records                  = 0;
      win_rate                         = 0.0;
      loss_rate                        = 0.0;
      profit_factor                    = 0.0;
      expectancy                       = 0.0;
      average_r                        = 0.0;
      median_r                         = 0.0;
      maximum_drawdown                 = 0.0;
      p95_drawdown                     = 0.0;
      maximum_losing_streak            = 0;
      symbol_distribution              = "EURUSDm:0;USDJPYm:0;XAUUSDm:0;BTCUSDm:0;ETHUSDm:0";
      direction_distribution           = "BUY:0;SELL:0";
      regime_distribution              = "UNKNOWN:0";
      confidence_quality_distribution  = "AVG_CONF:0.00;AVG_QUAL:0.00";
      temporal_distribution            = "M1:0";
      data_quality_statistics          = "GAPS:0;STALE:0;ANOMALIES:0;SIZING_REJ:0";
   }

   string ToCsv() const
   {
      return StringFormat("%s,%d,%I64d,%s,%s,%d,%d,%d,%d,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%.2f,%.2f,%d,%s,%s,%s,%s,%s,%s",
         milestone_name, milestone_target, (long)timestamp, cohort_id, config_fingerprint,
         sample_size, valid_records, invalid_records, warning_records,
         win_rate, loss_rate, profit_factor, expectancy, average_r, median_r,
         maximum_drawdown, p95_drawdown, maximum_losing_streak,
         symbol_distribution, direction_distribution, regime_distribution,
         confidence_quality_distribution, temporal_distribution, data_quality_statistics);
   }

   bool FromCsv(const string line)
   {
      string tokens[];
      int count = StringSplit(line, ',', tokens);
      if(count < 24) return false;

      milestone_name                  = tokens[0];
      milestone_target                = (int)StringToInteger(tokens[1]);
      timestamp                       = (datetime)StringToInteger(tokens[2]);
      cohort_id                       = tokens[3];
      config_fingerprint              = tokens[4];
      sample_size                     = (int)StringToInteger(tokens[5]);
      valid_records                   = (int)StringToInteger(tokens[6]);
      invalid_records                 = (int)StringToInteger(tokens[7]);
      warning_records                 = (int)StringToInteger(tokens[8]);
      win_rate                        = StringToDouble(tokens[9]);
      loss_rate                       = StringToDouble(tokens[10]);
      profit_factor                   = StringToDouble(tokens[11]);
      expectancy                      = StringToDouble(tokens[12]);
      average_r                       = StringToDouble(tokens[13]);
      median_r                        = StringToDouble(tokens[14]);
      maximum_drawdown                = StringToDouble(tokens[15]);
      p95_drawdown                    = StringToDouble(tokens[16]);
      maximum_losing_streak           = (int)StringToInteger(tokens[17]);
      symbol_distribution             = tokens[18];
      direction_distribution          = tokens[19];
      regime_distribution             = tokens[20];
      confidence_quality_distribution = tokens[21];
      temporal_distribution           = tokens[22];
      data_quality_statistics         = tokens[23];
      return true;
   }
};

//+------------------------------------------------------------------+
//| Daily Forward Evidence Snapshot Record                           |
//+------------------------------------------------------------------+
#define FORWARD_DAILY_SNAPSHOTS_HEADER "date_key,timestamp,cohort_id,trades_generated,trades_closed,sample_size,pnl,realized_r,drawdown,drawdown_pct,data_health,persistence_health,anomalies_count,anomalies_summary"

struct SForwardDailySnapshot
{
   string   date_key;               // "2026-10-05"
   datetime timestamp;
   string   cohort_id;
   int      trades_generated;
   int      trades_closed;
   int      sample_size;
   double   pnl;
   double   realized_r;
   double   drawdown;
   double   drawdown_pct;
   string   data_health;            // "HEALTHY", "WARNING", "DEGRADED"
   string   persistence_health;     // "READY", "ERRORS"
   int      anomalies_count;
   string   anomalies_summary;

   void Reset(const string d_key = "")
   {
      date_key            = d_key;
      timestamp           = 0;
      cohort_id           = "COHORT_01";
      trades_generated    = 0;
      trades_closed       = 0;
      sample_size         = 0;
      pnl                 = 0.0;
      realized_r          = 0.0;
      drawdown            = 0.0;
      drawdown_pct        = 0.0;
      data_health         = "HEALTHY";
      persistence_health  = "READY";
      anomalies_count     = 0;
      anomalies_summary   = "NONE";
   }

   string ToCsv() const
   {
      return StringFormat("%s,%I64d,%s,%d,%d,%d,%.2f,%.3f,%.2f,%.2f,%s,%s,%d,%s",
         date_key, (long)timestamp, cohort_id, trades_generated, trades_closed,
         sample_size, pnl, realized_r, drawdown, drawdown_pct,
         data_health, persistence_health, anomalies_count, anomalies_summary);
   }

   bool FromCsv(const string line)
   {
      string tokens[];
      int count = StringSplit(line, ',', tokens);
      if(count < 14) return false;

      date_key           = tokens[0];
      timestamp          = (datetime)StringToInteger(tokens[1]);
      cohort_id          = tokens[2];
      trades_generated   = (int)StringToInteger(tokens[3]);
      trades_closed      = (int)StringToInteger(tokens[4]);
      sample_size        = (int)StringToInteger(tokens[5]);
      pnl                = StringToDouble(tokens[6]);
      realized_r         = StringToDouble(tokens[7]);
      drawdown           = StringToDouble(tokens[8]);
      drawdown_pct       = StringToDouble(tokens[9]);
      data_health        = tokens[10];
      persistence_health = tokens[11];
      anomalies_count    = (int)StringToInteger(tokens[12]);
      anomalies_summary  = tokens[13];
      return true;
   }
};

//+------------------------------------------------------------------+
//| Weekly Forward Evidence Snapshot Record                          |
//+------------------------------------------------------------------+
#define FORWARD_WEEKLY_SNAPSHOTS_HEADER "week_key,timestamp,cohort_id,cumulative_trades,cumulative_pnl,cumulative_r,win_rate,profit_factor,regime_breakdown,symbol_breakdown,drawdown,max_win_streak,max_loss_streak,evidence_quality,changes_from_prev_week"

struct SForwardWeeklySnapshot
{
   string   week_key;               // "2026-W40"
   datetime timestamp;
   string   cohort_id;
   int      cumulative_trades;
   double   cumulative_pnl;
   double   cumulative_r;
   double   win_rate;
   double   profit_factor;
   string   regime_breakdown;
   string   symbol_breakdown;
   double   drawdown;
   int      max_win_streak;
   int      max_loss_streak;
   string   evidence_quality;       // "CLEAN", "WARNINGS_NOTED"
   string   changes_from_prev_week;

   void Reset(const string w_key = "")
   {
      week_key               = w_key;
      timestamp              = 0;
      cohort_id              = "COHORT_01";
      cumulative_trades      = 0;
      cumulative_pnl         = 0.0;
      cumulative_r           = 0.0;
      win_rate               = 0.0;
      profit_factor          = 0.0;
      regime_breakdown       = "NONE";
      symbol_breakdown       = "NONE";
      drawdown               = 0.0;
      max_win_streak         = 0;
      max_loss_streak        = 0;
      evidence_quality       = "CLEAN";
      changes_from_prev_week = "BASELINE";
   }

   string ToCsv() const
   {
      return StringFormat("%s,%I64d,%s,%d,%.2f,%.3f,%.2f,%.2f,%s,%s,%.2f,%d,%d,%s,%s",
         week_key, (long)timestamp, cohort_id, cumulative_trades, cumulative_pnl,
         cumulative_r, win_rate, profit_factor, regime_breakdown, symbol_breakdown,
         drawdown, max_win_streak, max_loss_streak, evidence_quality, changes_from_prev_week);
   }

   bool FromCsv(const string line)
   {
      string tokens[];
      int count = StringSplit(line, ',', tokens);
      if(count < 15) return false;

      week_key               = tokens[0];
      timestamp              = (datetime)StringToInteger(tokens[1]);
      cohort_id              = tokens[2];
      cumulative_trades      = (int)StringToInteger(tokens[3]);
      cumulative_pnl         = StringToDouble(tokens[4]);
      cumulative_r           = StringToDouble(tokens[5]);
      win_rate               = StringToDouble(tokens[6]);
      profit_factor          = StringToDouble(tokens[7]);
      regime_breakdown       = tokens[8];
      symbol_breakdown       = tokens[9];
      drawdown               = StringToDouble(tokens[10]);
      max_win_streak         = (int)StringToInteger(tokens[11]);
      max_loss_streak        = (int)StringToInteger(tokens[12]);
      evidence_quality       = tokens[13];
      changes_from_prev_week = tokens[14];
      return true;
   }
};

//+------------------------------------------------------------------+
//| Monthly Forward Evidence Validation Snapshot Record              |
//+------------------------------------------------------------------+
#define FORWARD_MONTHLY_SNAPSHOTS_HEADER "month_key,timestamp,cohort_id,total_trades,win_rate,profit_factor,expectancy,sharpe_ratio,sortino_ratio,robustness_survival,evidence_class,recommendation"

struct SForwardMonthlySnapshot
{
   string   month_key;              // "2026-10"
   datetime timestamp;
   string   cohort_id;
   int      total_trades;
   double   win_rate;
   double   profit_factor;
   double   expectancy;
   double   sharpe_ratio;
   double   sortino_ratio;
   string   robustness_survival;    // "PASSED", "DEGRADED", "FAILED", "INSUFFICIENT"
   string   evidence_class;         // "INSUFFICIENT_SAMPLE", "PRELIMINARY", "ROBUST"
   string   recommendation;         // "CONTINUE_COLLECTING", "STOP", "PROCEED"

   void Reset(const string m_key = "")
   {
      month_key           = m_key;
      timestamp           = 0;
      cohort_id           = "COHORT_01";
      total_trades        = 0;
      win_rate            = 0.0;
      profit_factor       = 0.0;
      expectancy          = 0.0;
      sharpe_ratio        = 0.0;
      sortino_ratio       = 0.0;
      robustness_survival = "INSUFFICIENT";
      evidence_class      = "INSUFFICIENT_SAMPLE";
      recommendation      = "CONTINUE_COLLECTING";
   }

   string ToCsv() const
   {
      return StringFormat("%s,%I64d,%s,%d,%.2f,%.2f,%.3f,%.2f,%.2f,%s,%s,%s",
         month_key, (long)timestamp, cohort_id, total_trades, win_rate, profit_factor,
         expectancy, sharpe_ratio, sortino_ratio, robustness_survival, evidence_class, recommendation);
   }

   bool FromCsv(const string line)
   {
      string tokens[];
      int count = StringSplit(line, ',', tokens);
      if(count < 12) return false;

      month_key           = tokens[0];
      timestamp           = (datetime)StringToInteger(tokens[1]);
      cohort_id           = tokens[2];
      total_trades        = (int)StringToInteger(tokens[3]);
      win_rate            = StringToDouble(tokens[4]);
      profit_factor       = StringToDouble(tokens[5]);
      expectancy          = StringToDouble(tokens[6]);
      sharpe_ratio        = StringToDouble(tokens[7]);
      sortino_ratio       = StringToDouble(tokens[8]);
      robustness_survival = tokens[9];
      evidence_class      = tokens[10];
      recommendation      = tokens[11];
      return true;
   }
};

//+------------------------------------------------------------------+
//| Periodic Snapshot Records (Daily / Weekly / Monthly Legacy)       |
//+------------------------------------------------------------------+
struct SForwardSnapshotRecord
{
   string   period_type;      // "DAILY", "WEEKLY", "MONTHLY"
   string   period_key;       // "2026-10-04", "2026-W40", "2026-10"
   datetime timestamp;
   int      trades_closed;
   int      wins;
   int      losses;
   double   win_rate;
   double   net_pnl;
   double   avg_r;
   double   expectancy;
   double   current_equity;
   double   max_drawdown;
   double   max_drawdown_pct;
   int      quality_warnings;
   int      quality_invalids;
   string   cohort_id;
   string   config_fingerprint;

   void Reset(const string p_type = "DAILY", const string p_key = "")
   {
      period_type        = p_type;
      period_key         = p_key;
      timestamp          = 0;
      trades_closed      = 0;
      wins               = 0;
      losses             = 0;
      win_rate           = 0.0;
      net_pnl            = 0.0;
      avg_r              = 0.0;
      expectancy         = 0.0;
      current_equity     = 10.00;
      max_drawdown       = 0.0;
      max_drawdown_pct   = 0.0;
      quality_warnings   = 0;
      quality_invalids   = 0;
      cohort_id          = "";
      config_fingerprint = "";
   }

   string ToCsv() const
   {
      return StringFormat("%s,%s,%I64d,%d,%d,%d,%.2f,%.2f,%.3f,%.3f,%.2f,%.2f,%.2f,%d,%d,%s,%s",
         period_type, period_key, (long)timestamp, trades_closed, wins, losses,
         win_rate, net_pnl, avg_r, expectancy, current_equity, max_drawdown,
         max_drawdown_pct, quality_warnings, quality_invalids, cohort_id, config_fingerprint);
   }

   bool FromCsv(const string line)
   {
      string tokens[];
      int count = StringSplit(line, ',', tokens);
      if(count != 17) return false;

      period_type        = tokens[0];
      period_key         = tokens[1];
      timestamp          = (datetime)StringToInteger(tokens[2]);
      trades_closed      = (int)StringToInteger(tokens[3]);
      wins               = (int)StringToInteger(tokens[4]);
      losses             = (int)StringToInteger(tokens[5]);
      win_rate           = StringToDouble(tokens[6]);
      net_pnl            = StringToDouble(tokens[7]);
      avg_r              = StringToDouble(tokens[8]);
      expectancy         = StringToDouble(tokens[9]);
      current_equity     = StringToDouble(tokens[10]);
      max_drawdown       = StringToDouble(tokens[11]);
      max_drawdown_pct   = StringToDouble(tokens[12]);
      quality_warnings   = (int)StringToInteger(tokens[13]);
      quality_invalids   = (int)StringToInteger(tokens[14]);
      cohort_id          = tokens[15];
      config_fingerprint = tokens[16];
      return true;
   }
};

#endif
