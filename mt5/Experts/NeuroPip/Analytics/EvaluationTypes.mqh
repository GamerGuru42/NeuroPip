//+------------------------------------------------------------------+
//| EvaluationTypes.mqh                                              |
//| ATG Trading Engine - Phase 8                                     |
//| Extended Paper Validation & Statistical Evaluation Types         |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_EVALUATION_TYPES_MQH
#define ATG_EVALUATION_TYPES_MQH

#include "../Simulation/PaperTradeTypes.mqh"
#include "../Persistence/PersistenceTypes.mqh"
#include "../Intelligence/MarketRegimeTypes.mqh"
#include "../Execution/TradeTypes.mqh"

//+------------------------------------------------------------------+
//| Dataset Integrity & Health Status                                |
//+------------------------------------------------------------------+
enum ENUM_DATASET_STATUS
{
   DATASET_STATUS_EMPTY = 0,
   DATASET_STATUS_VALID,
   DATASET_STATUS_PARTIAL_ANOMALIES,
   DATASET_STATUS_CORRUPTED,
   DATASET_STATUS_INSUFFICIENT
};

inline string DatasetStatusToString(ENUM_DATASET_STATUS status)
{
   switch(status)
   {
      case DATASET_STATUS_EMPTY:             return "DATASET_EMPTY";
      case DATASET_STATUS_VALID:             return "DATASET_VALID";
      case DATASET_STATUS_PARTIAL_ANOMALIES: return "DATASET_PARTIAL_ANOMALIES";
      case DATASET_STATUS_CORRUPTED:         return "DATASET_CORRUPTED";
      case DATASET_STATUS_INSUFFICIENT:      return "DATASET_INSUFFICIENT";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Sample Size Classification Tier                                  |
//+------------------------------------------------------------------+
enum ENUM_SAMPLE_CLASSIFICATION
{
   SAMPLE_INSUFFICIENT = 0,    // < 15 trades
   SAMPLE_PRELIMINARY,         // 15 - 29 trades
   SAMPLE_ADEQUATE_FOR_EVALUATION // >= 30 trades
};

inline string SampleClassificationToString(ENUM_SAMPLE_CLASSIFICATION cls)
{
   switch(cls)
   {
      case SAMPLE_INSUFFICIENT:             return "INSUFFICIENT_SAMPLE";
      case SAMPLE_PRELIMINARY:              return "PRELIMINARY";
      case SAMPLE_ADEQUATE_FOR_EVALUATION:  return "ADEQUATE_FOR_EVALUATION";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Statistical Evidence Classification                              |
//+------------------------------------------------------------------+
enum ENUM_EVIDENCE_CLASSIFICATION
{
   EVIDENCE_NO_EVIDENCE = 0,
   EVIDENCE_INSUFFICIENT_SAMPLE,
   EVIDENCE_PRELIMINARY_EVIDENCE,
   EVIDENCE_PROMISING_BUT_UNCONFIRMED,
   EVIDENCE_ROBUST_PAPER_EVIDENCE
};

inline string EvidenceClassificationToString(ENUM_EVIDENCE_CLASSIFICATION cls)
{
   switch(cls)
   {
      case EVIDENCE_NO_EVIDENCE:                return "NO_EVIDENCE";
      case EVIDENCE_INSUFFICIENT_SAMPLE:        return "INSUFFICIENT_SAMPLE";
      case EVIDENCE_PRELIMINARY_EVIDENCE:       return "PRELIMINARY_EVIDENCE";
      case EVIDENCE_PROMISING_BUT_UNCONFIRMED:  return "PROMISING_BUT_UNCONFIRMED";
      case EVIDENCE_ROBUST_PAPER_EVIDENCE:      return "ROBUST_PAPER_EVIDENCE";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Distribution Metrics (Percentiles & Dispersion)                  |
//+------------------------------------------------------------------+
struct SDistributionMetrics
{
   int    count;
   double mean;
   double median;          // P50
   double std_dev;
   double min_val;
   double max_val;
   double p10;
   double p25;
   double p75;
   double p90;

   void Reset()
   {
      count   = 0;
      mean    = 0.0;
      median  = 0.0;
      std_dev = 0.0;
      min_val = 0.0;
      max_val = 0.0;
      p10     = 0.0;
      p25     = 0.0;
      p75     = 0.0;
      p90     = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Dataset Validation & Audit Report                                |
//+------------------------------------------------------------------+
struct SDatasetValidationReport
{
   ENUM_DATASET_STATUS status;
   int                 total_records;
   int                 valid_records;
   int                 rejected_records;
   int                 duplicates_count;
   int                 missing_fields_count;
   datetime            data_start;
   datetime            data_end;
   int                 symbol_count;
   int                 strategy_count;
   string              validation_notes;

   void Reset()
   {
      status               = DATASET_STATUS_EMPTY;
      total_records        = 0;
      valid_records        = 0;
      rejected_records     = 0;
      duplicates_count     = 0;
      missing_fields_count = 0;
      data_start           = 0;
      data_end             = 0;
      symbol_count         = 0;
      strategy_count       = 0;
      validation_notes     = "";
   }
};

//+------------------------------------------------------------------+
//| Per-Symbol Statistical Evaluation                                |
//+------------------------------------------------------------------+
struct SSymbolEvaluation
{
   string                     symbol;
   int                        sample_size;
   int                        wins;
   int                        losses;
   int                        breakevens;
   double                     win_rate;
   double                     loss_rate;
   double                     gross_profit;
   double                     gross_loss;
   double                     net_pnl;
   double                     profit_factor;
   double                     avg_r;
   double                     median_r;
   double                     expectancy;
   double                     max_drawdown;
   double                     max_drawdown_pct;
   int                        avg_duration_sec;
   ENUM_SAMPLE_CLASSIFICATION sample_tier;
   string                     regime_distribution;

   void Reset(const string sym = "")
   {
      symbol               = sym;
      sample_size          = 0;
      wins                 = 0;
      losses               = 0;
      breakevens           = 0;
      win_rate             = 0.0;
      loss_rate            = 0.0;
      gross_profit         = 0.0;
      gross_loss           = 0.0;
      net_pnl              = 0.0;
      profit_factor        = 0.0;
      avg_r                = 0.0;
      median_r             = 0.0;
      expectancy           = 0.0;
      max_drawdown         = 0.0;
      max_drawdown_pct     = 0.0;
      avg_duration_sec     = 0;
      sample_tier          = SAMPLE_INSUFFICIENT;
      regime_distribution  = "";
   }
};

//+------------------------------------------------------------------+
//| Per-Regime Statistical Evaluation                                |
//+------------------------------------------------------------------+
struct SRegimeEvaluation
{
   ENUM_ATG_MARKET_REGIME regime;
   string                 regime_name;
   int                    trades;
   int                    wins;
   int                    losses;
   double                 win_rate;
   double                 net_pnl;
   double                 avg_r;
   double                 median_r;
   double                 expectancy;
   double                 profit_factor;
   double                 max_drawdown;
   int                    buy_count;
   int                    sell_count;

   void Reset(ENUM_ATG_MARKET_REGIME reg = REGIME_INSUFFICIENT_DATA)
   {
      regime        = reg;
      regime_name   = MarketRegimeToString(reg);
      trades        = 0;
      wins          = 0;
      losses        = 0;
      win_rate      = 0.0;
      net_pnl       = 0.0;
      avg_r         = 0.0;
      median_r      = 0.0;
      expectancy    = 0.0;
      profit_factor = 0.0;
      max_drawdown  = 0.0;
      buy_count     = 0;
      sell_count    = 0;
   }
};

//+------------------------------------------------------------------+
//| Directional Evaluation (BUY vs SELL)                             |
//+------------------------------------------------------------------+
struct SDirectionEvaluation
{
   ENUM_ATG_TRADE_DIRECTION direction;
   string                   direction_name;
   int                      trades;
   int                      wins;
   int                      losses;
   double                   win_rate;
   double                   net_pnl;
   double                   avg_r;
   double                   median_r;
   double                   expectancy;
   double                   profit_factor;
   double                   max_drawdown;
   int                      avg_duration_sec;

   void Reset(ENUM_ATG_TRADE_DIRECTION dir = ATG_DIRECTION_NONE)
   {
      direction        = dir;
      direction_name   = (dir == ATG_DIRECTION_BUY) ? "BUY" : (dir == ATG_DIRECTION_SELL ? "SELL" : "NONE");
      trades           = 0;
      wins             = 0;
      losses           = 0;
      win_rate         = 0.0;
      net_pnl          = 0.0;
      avg_r            = 0.0;
      median_r         = 0.0;
      expectancy       = 0.0;
      profit_factor    = 0.0;
      max_drawdown     = 0.0;
      avg_duration_sec = 0;
   }
};

//+------------------------------------------------------------------+
//| Equity Curve Progression & Volatility Metrics                    |
//+------------------------------------------------------------------+
struct SEquityCurveAnalysis
{
   double initial_equity;
   double final_equity;
   double peak_equity;
   double net_pnl;
   double max_drawdown;
   double max_drawdown_pct;
   int    drawdown_duration_sec;
   double recovery_factor;           // Net P&L / Max Drawdown
   double equity_volatility;         // Std Dev of equity trade changes
   int    max_consecutive_wins;
   int    max_consecutive_losses;

   void Reset()
   {
      initial_equity         = 1000.0;
      final_equity           = 1000.0;
      peak_equity            = 1000.0;
      net_pnl                = 0.0;
      max_drawdown           = 0.0;
      max_drawdown_pct       = 0.0;
      drawdown_duration_sec  = 0;
      recovery_factor        = 0.0;
      equity_volatility      = 0.0;
      max_consecutive_wins   = 0;
      max_consecutive_losses = 0;
   }
};

//+------------------------------------------------------------------+
//| Risk Contract Audit Report                                       |
//+------------------------------------------------------------------+
struct SRiskValidationReport
{
   int    total_audited;
   int    valid_risk_percent_count;
   int    valid_risk_money_count;
   int    valid_lot_step_count;
   int    valid_stop_distance_count;
   int    valid_min_rr_count;
   int    valid_spread_count;
   int    violations_count;
   string violation_details;

   void Reset()
   {
      total_audited             = 0;
      valid_risk_percent_count  = 0;
      valid_risk_money_count    = 0;
      valid_lot_step_count      = 0;
      valid_stop_distance_count = 0;
      valid_min_rr_count        = 0;
      valid_spread_count        = 0;
      violations_count          = 0;
      violation_details         = "NONE";
   }
};

//+------------------------------------------------------------------+
//| Trade Quality & Confluence Score Correlation                     |
//+------------------------------------------------------------------+
struct STradeQualityAnalysis
{
   int    total_trades;
   int    high_confidence_trades;
   double high_confidence_win_rate;
   double high_confidence_avg_r;
   int    low_confidence_trades;
   double low_confidence_win_rate;
   double low_confidence_avg_r;

   int    high_quality_trades;
   double high_quality_win_rate;
   double high_quality_avg_r;
   int    low_quality_trades;
   double low_quality_win_rate;
   double low_quality_avg_r;

   string explanation;

   void Reset()
   {
      total_trades              = 0;
      high_confidence_trades    = 0;
      high_confidence_win_rate  = 0.0;
      high_confidence_avg_r     = 0.0;
      low_confidence_trades     = 0;
      low_confidence_win_rate   = 0.0;
      low_confidence_avg_r      = 0.0;
      high_quality_trades       = 0;
      high_quality_win_rate     = 0.0;
      high_quality_avg_r        = 0.0;
      low_quality_trades        = 0;
      low_quality_win_rate      = 0.0;
      low_quality_avg_r         = 0.0;
      explanation               = "";
   }
};

//+------------------------------------------------------------------+
//| Out-of-Sample Partitioning Result                                |
//+------------------------------------------------------------------+
struct SOutOfSampleResult
{
   string status;             // "SPLIT_VALID", "INSUFFICIENT_DATA"
   int    train_count;
   double train_win_rate;
   double train_avg_r;
   double train_expectancy;

   int    val_count;
   double val_win_rate;
   double val_avg_r;
   double val_expectancy;

   int    oos_count;
   double oos_win_rate;
   double oos_avg_r;
   double oos_expectancy;
   double oos_degradation_pct; // Difference in expectancy %

   void Reset()
   {
      status              = "INSUFFICIENT_DATA";
      train_count         = 0;
      train_win_rate      = 0.0;
      train_avg_r         = 0.0;
      train_expectancy    = 0.0;
      val_count           = 0;
      val_win_rate        = 0.0;
      val_avg_r           = 0.0;
      val_expectancy      = 0.0;
      oos_count           = 0;
      oos_win_rate        = 0.0;
      oos_avg_r           = 0.0;
      oos_expectancy      = 0.0;
      oos_degradation_pct = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Walk-Forward Sequential Window Result                            |
//+------------------------------------------------------------------+
struct SWalkForwardResult
{
   string status;             // "WALK_FORWARD_VALID", "INSUFFICIENT_DATA"
   int    windows_tested;
   int    windows_positive;
   double walk_forward_efficiency; // OOS Expectancy / In-Sample Expectancy
   string summary;

   void Reset()
   {
      status                  = "INSUFFICIENT_DATA";
      windows_tested          = 0;
      windows_positive        = 0;
      walk_forward_efficiency = 0.0;
      summary                 = "INSUFFICIENT_DATA (< 40 trades)";
   }
};

//+------------------------------------------------------------------+
//| Monte Carlo Bootstrap Resampling Result                          |
//+------------------------------------------------------------------+
struct SMonteCarloResult
{
   string status;             // "SIMULATED_BOOTSTRAP", "INSUFFICIENT_DATA"
   int    simulations_count;
   double median_drawdown;
   double p95_drawdown;
   double max_drawdown_observed;
   int    median_consecutive_losses;
   int    p95_consecutive_losses;
   double prob_drawdown_exceeding_10pct;
   double prob_drawdown_exceeding_20pct;

   void Reset()
   {
      status                        = "INSUFFICIENT_DATA";
      simulations_count             = 0;
      median_drawdown               = 0.0;
      p95_drawdown                  = 0.0;
      max_drawdown_observed         = 0.0;
      median_consecutive_losses     = 0;
      p95_consecutive_losses        = 0;
      prob_drawdown_exceeding_10pct = 0.0;
      prob_drawdown_exceeding_20pct = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Robustness Sensitivity Checks                                    |
//+------------------------------------------------------------------+
struct SRobustnessResult
{
   double baseline_expectancy;
   double adverse_slippage_expectancy;     // Simulated -0.05R slippage penalty
   double wider_spread_expectancy;         // Simulated -0.05R spread penalty
   double same_bar_worst_case_expectancy;
   string edge_survival_status;            // "ROBUST_SURVIVAL", "MARGINAL_EDGE", "EDGE_ERODED", "INSUFFICIENT_DATA"

   void Reset()
   {
      baseline_expectancy             = 0.0;
      adverse_slippage_expectancy     = 0.0;
      wider_spread_expectancy         = 0.0;
      same_bar_worst_case_expectancy  = 0.0;
      edge_survival_status            = "INSUFFICIENT_DATA";
   }
};

//+------------------------------------------------------------------+
//| Master Phase 8 Evaluation Result Structure                       |
//+------------------------------------------------------------------+
struct SPhase8EvaluationResult
{
   datetime                     generated_time;
   string                       strategy_name;

   // Integrity & Sample
   SDatasetValidationReport     dataset_report;
   ENUM_SAMPLE_CLASSIFICATION   sample_tier;

   // Overall Core Metrics
   int                          total_trades;
   int                          winning_trades;
   int                          losing_trades;
   int                          breakeven_trades;
   double                       win_rate;
   double                       loss_rate;
   double                       gross_profit;
   double                       gross_loss;
   double                       net_pnl;
   double                       profit_factor;
   double                       avg_win;
   double                       avg_loss;
   double                       avg_r;
   double                       median_r;
   double                       expectancy;
   double                       max_drawdown;
   double                       max_drawdown_pct;
   int                          max_win_streak;
   int                          max_loss_streak;
   int                          avg_duration_sec;
   int                          longest_duration_sec;

   // Distributions
   SDistributionMetrics         r_distribution;
   SDistributionMetrics         pnl_distribution;
   SDistributionMetrics         duration_distribution;

   // Categorical & Temporal Breakdowns
   SSymbolEvaluation            symbol_evaluations[];
   SRegimeEvaluation            regime_evaluations[];
   SDirectionEvaluation         direction_evaluations[];  // 0: BUY, 1: SELL
   STimePeriodPerformance       daily_evaluations[];
   STimePeriodPerformance       weekly_evaluations[];
   STimePeriodPerformance       monthly_evaluations[];

   // Detailed Layers
   SEquityCurveAnalysis         equity_analysis;
   SRiskValidationReport        risk_report;
   STradeQualityAnalysis        quality_analysis;
   SOutOfSampleResult           oos_result;
   SWalkForwardResult           walk_forward_result;
   SMonteCarloResult            monte_carlo_result;
   SRobustnessResult            robustness_result;

   // Final Evidence Verdict
   ENUM_EVIDENCE_CLASSIFICATION evidence_class;
   string                       limitations_summary;

   void ResetCorePerformance()
   {
      total_trades         = 0;
      winning_trades       = 0;
      losing_trades        = 0;
      breakeven_trades     = 0;
      win_rate             = 0.0;
      loss_rate            = 0.0;
      gross_profit         = 0.0;
      gross_loss           = 0.0;
      net_pnl              = 0.0;
      profit_factor        = 0.0;
      avg_win              = 0.0;
      avg_loss             = 0.0;
      avg_r                = 0.0;
      median_r             = 0.0;
      expectancy           = 0.0;
      max_drawdown         = 0.0;
      max_drawdown_pct     = 0.0;
      max_win_streak       = 0;
      max_loss_streak      = 0;
      avg_duration_sec     = 0;
      longest_duration_sec = 0;
      sample_tier          = SAMPLE_INSUFFICIENT;

      r_distribution.Reset();
      pnl_distribution.Reset();
      duration_distribution.Reset();
   }

   void Reset()
   {
      generated_time       = 0;
      strategy_name        = "ATG_TREND_CONTINUATION";
      dataset_report.Reset();

      ResetCorePerformance();

      ArrayResize(symbol_evaluations, 0);
      ArrayResize(regime_evaluations, 0);
      ArrayResize(direction_evaluations, 2);
      direction_evaluations[0].Reset(ATG_DIRECTION_BUY);
      direction_evaluations[1].Reset(ATG_DIRECTION_SELL);
      ArrayResize(daily_evaluations, 0);
      ArrayResize(weekly_evaluations, 0);
      ArrayResize(monthly_evaluations, 0);

      equity_analysis.Reset();
      risk_report.Reset();
      quality_analysis.Reset();
      oos_result.Reset();
      walk_forward_result.Reset();
      monte_carlo_result.Reset();
      robustness_result.Reset();

      evidence_class       = EVIDENCE_INSUFFICIENT_SAMPLE;
      limitations_summary  = "Paper trading simulation; execution assumptions do not model real broker slippage or book depth.";
   }
};

#endif
