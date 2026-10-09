//+------------------------------------------------------------------+
//| Config.mqh                                                        |
//| NeuroPip - Phase 5 Configuration                        |
//+------------------------------------------------------------------+
#property copyright "NextGen Technologies"
#property link      ""

//+------------------------------------------------------------------+
//| Logging levels                                                    |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_DEBUG,
   LOG_LEVEL_INFO,
   LOG_LEVEL_NOTICE,
   LOG_LEVEL_WARNING,
   LOG_LEVEL_ERROR,
   LOG_LEVEL_CRITICAL
};

//+------------------------------------------------------------------+
//| ATG Configuration                                                 |
//+------------------------------------------------------------------+
class CConfig
{
public:

   // ---------------------------------------------------------------
   // Versioning
   // ---------------------------------------------------------------
   string ea_version;
   string config_version;

   // ---------------------------------------------------------------
   // Runtime scheduling
   // ---------------------------------------------------------------
   int timer_interval_ms;

   // ---------------------------------------------------------------
   // Market universe
   // ---------------------------------------------------------------
   string symbol_universe[];

   // ---------------------------------------------------------------
   // Timeframes used by market-data layer
   // ---------------------------------------------------------------
   ENUM_TIMEFRAMES enabled_timeframes[];

   // ---------------------------------------------------------------
   // Diagnostics / logging
   // ---------------------------------------------------------------
   ENUM_LOG_LEVEL logging_level;
   int diagnostic_interval_sec;

   // ---------------------------------------------------------------
   // Phase 5 Trade Planning Configuration
   // ---------------------------------------------------------------
   double risk_percent;
   double min_reward_risk;
   double sl_atr_multiplier;
   double tp_rr_multiplier;
   int    max_spread_tolerance;
   int    plan_expiry_sec;
   double entry_buffer_points;

   // ---------------------------------------------------------------
   // Phase 6 Paper Trading & Simulation Configuration
   // ---------------------------------------------------------------
   bool   paper_trading_enabled;
   double initial_paper_equity;
   int    min_performance_sample;
   string same_bar_policy;
   string simulation_cost_model;
   string slippage_model;

   // ---------------------------------------------------------------
   // Phase 7 Persistence & Historical Analytics Configuration
   // ---------------------------------------------------------------
   bool   persistence_enabled;
   int    storage_schema_version;
   string persistence_directory;
   bool   audit_logging_enabled;
   bool   historical_analytics_enabled;

   // ---------------------------------------------------------------
   // Phase 8 Extended Paper Validation & Statistical Evaluation Configuration
   // ---------------------------------------------------------------
   bool   statistical_evaluation_enabled;
   int    min_evaluation_sample;
   int    monte_carlo_runs;

   // ---------------------------------------------------------------
   // Strategy Selection & Timeframe (Phase 10 Track B Configuration)
   // ---------------------------------------------------------------
   string            active_strategy_id;
   ENUM_TIMEFRAMES   strategy_tf;

   // ---------------------------------------------------------------
   // Phase 9 Forward Paper Validation & Evidence Collection Configuration
   // ---------------------------------------------------------------
   bool   forward_validation_enabled;
   string active_cohort_id;
   int    forward_evidence_target;
   int    forward_evidence_extended_target;
   bool   enforce_config_freeze;

   //+--------------------------------------------------------------+
   //| Constructor                                                    |
   //+--------------------------------------------------------------+
   CConfig()
   {
      // ------------------------------------------------------------
      // Strategy Selection & Timeframe Defaults (Track B)
      // ------------------------------------------------------------
      active_strategy_id = "NEUROPIP_MOMENTUM_BREAKOUT";
      strategy_tf        = PERIOD_H1;
      // ------------------------------------------------------------
      // Version
      // ------------------------------------------------------------
      ea_version     = "0.9.0";
      config_version = "2.0.0";

      // ------------------------------------------------------------
      // Timer
      // ------------------------------------------------------------
      timer_interval_ms = 100;

      // ------------------------------------------------------------
      // Exness demo symbol universe
      // ------------------------------------------------------------
      string symbols[] =
      {
         "EURUSDm",
         "USDJPYm",
         "XAUUSDm",
         "BTCUSDm",
         "ETHUSDm"
      };

      int symbol_count = ArraySize(symbols);
      ArrayResize(symbol_universe, symbol_count);
      for(int i = 0; i < symbol_count; i++)
      {
         symbol_universe[i] = symbols[i];
      }

      // ------------------------------------------------------------
      // Enabled timeframes
      // ------------------------------------------------------------
      ENUM_TIMEFRAMES tfs[] =
      {
         PERIOD_M1,
         PERIOD_M5,
         PERIOD_M15,
         PERIOD_H1,
         PERIOD_H4,
         PERIOD_D1
      };

      int timeframe_count = ArraySize(tfs);
      ArrayResize(enabled_timeframes, timeframe_count);
      for(int i = 0; i < timeframe_count; i++)
      {
         enabled_timeframes[i] = tfs[i];
      }

      // ------------------------------------------------------------
      // Logging
      // ------------------------------------------------------------
      logging_level = LOG_LEVEL_DEBUG;

      // ------------------------------------------------------------
      // Periodic diagnostics
      // ------------------------------------------------------------
      diagnostic_interval_sec = 60;

      // ------------------------------------------------------------
      // Phase 5 Trade Planning parameters
      // ------------------------------------------------------------
      risk_percent         = 1.0;     // 1.0% equity risk per trade
      min_reward_risk      = 1.5;     // 1.50 minimum R:R ratio
      sl_atr_multiplier    = 2.0;     // 2.0x ATR for Stop Loss
      tp_rr_multiplier     = 2.5;     // 2.5x R:R for Take Profit (Breakout target)
      max_spread_tolerance = 40;      // 40 points max spread
      plan_expiry_sec      = 1800;    // 30 minutes validity window
      entry_buffer_points  = 0.0;

      // ------------------------------------------------------------
      // Phase 6 Paper Trading & Simulation parameters
      // ------------------------------------------------------------
      paper_trading_enabled  = true;
      initial_paper_equity   = 1000.00; // Track B Configurable Paper Equity ($1,000.00 realistic retail test balance)
      min_performance_sample = 30;
      same_bar_policy        = "CONSERVATIVE_SL";
      simulation_cost_model  = "ZERO_COST_DEMO";
      slippage_model         = "NONE";

      // ------------------------------------------------------------
      // Phase 7 Persistence & Historical Analytics parameters
      // ------------------------------------------------------------
      persistence_enabled          = true;
      storage_schema_version       = 2;
      persistence_directory        = "ATG_Simulation";
      audit_logging_enabled        = true;
      historical_analytics_enabled = true;

      // ------------------------------------------------------------
      // Phase 8 Statistical Evaluation parameters
      // ------------------------------------------------------------
      statistical_evaluation_enabled = true;
      min_evaluation_sample          = 30;
      monte_carlo_runs               = 500;

      // ------------------------------------------------------------
      // Phase 9 Forward Paper Validation & Evidence Collection parameters
      // ------------------------------------------------------------
      forward_validation_enabled       = true;
      active_cohort_id                 = "COHORT_EXP_01"; // Track B Experimental Cohort
      forward_evidence_target          = 50;
      forward_evidence_extended_target = 100;
      enforce_config_freeze            = false;
   }
};