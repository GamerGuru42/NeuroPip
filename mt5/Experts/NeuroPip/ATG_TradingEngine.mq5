//+------------------------------------------------------------------+
//| ATG_TradingEngine.mq5                                            |
//| ATG Trading Engine - Phase 9                                     |
//|                                                                  |
//| Phase 9: Forward Paper Validation, Monitoring & Evidence Collect |
//|          Frozen Configuration & Real Market Data Validation      |
//|                                                                  |
//| SAFETY: Trading remains DISABLED.                               |
//|                                                                  |
//| NO OrderSend()                                                   |
//| NO CTrade.Buy()                                                   |
//| NO CTrade.Sell()                                                  |
//| NO live execution                                                 |
//+------------------------------------------------------------------+

#property copyright "ATG"
#property link      ""
#property version   "2.00"


//-------------------------------------------------------------------
// Configuration
//-------------------------------------------------------------------
#include "Config/Config.mqh"


//-------------------------------------------------------------------
// Diagnostics
//-------------------------------------------------------------------
#include "Diagnostics/Logger.mqh"


//-------------------------------------------------------------------
// Core
//-------------------------------------------------------------------
#include "Core/RuntimeState.mqh"
#include "Core/RuntimeValidator.mqh"
#include "Core/EventScheduler.mqh"


//-------------------------------------------------------------------
// Security
//-------------------------------------------------------------------
#include "Security/Capabilities.mqh"


//-------------------------------------------------------------------
// Market Data
//-------------------------------------------------------------------
#include "MarketData/SymbolUniverseManager.mqh"
#include "MarketData/MarketStateCache.mqh"
#include "MarketData/BarDataManager.mqh"
#include "MarketData/MarketDataEngine.mqh"


//-------------------------------------------------------------------
// Execution
//-------------------------------------------------------------------
#include "Execution/TradeTypes.mqh"
#include "Execution/ExecutionGuard.mqh"
#include "Execution/ExecutionValidator.mqh"
#include "Execution/OrderCheckEngine.mqh"
#include "Execution/RiskEngine.mqh"
#include "Execution/PositionSizer.mqh"
#include "Execution/ExecutionRequestBuilder.mqh"
#include "Execution/ExecutionReconciliation.mqh"
#include "Execution/ExecutionPipeline.mqh"


//-------------------------------------------------------------------
// Market Intelligence (Phase 3)
//-------------------------------------------------------------------
#include "Intelligence/MarketFeatureTypes.mqh"
#include "Intelligence/MarketRegimeTypes.mqh"
#include "Intelligence/SignalTypes.mqh"
#include "Intelligence/MarketFeatureEngine.mqh"
#include "Intelligence/MarketRegimeEngine.mqh"
#include "Intelligence/SignalEngine.mqh"
#include "Intelligence/MarketIntelligenceEngine.mqh"


//-------------------------------------------------------------------
// Strategy Decision Engine (Phase 4)
//-------------------------------------------------------------------
#include "Strategy/StrategyTypes.mqh"
#include "Strategy/StrategyValidator.mqh"
#include "Strategy/TrendContinuationStrategy.mqh"
#include "Strategy/StrategyDecisionEngine.mqh"


//-------------------------------------------------------------------
// Trade Planning Layer (Phase 5)
//-------------------------------------------------------------------
#include "Strategy/TradePlanTypes.mqh"
#include "Strategy/TradePlanner.mqh"


//-------------------------------------------------------------------
// Simulation & Paper Trading (Phase 6)
//-------------------------------------------------------------------
#include "Simulation/PaperTradeTypes.mqh"
#include "Simulation/PerformanceEngine.mqh"
#include "Simulation/PaperTradingEngine.mqh"


//-------------------------------------------------------------------
// Persistence & Historical Analytics (Phase 7)
//-------------------------------------------------------------------
#include "Persistence/PersistenceTypes.mqh"
#include "Persistence/PaperTradeStorage.mqh"
#include "Persistence/HistoricalAnalyticsEngine.mqh"


//-------------------------------------------------------------------
// Extended Paper Validation & Statistical Evaluation (Phase 8)
//-------------------------------------------------------------------
#include "Analytics/EvaluationTypes.mqh"
#include "Analytics/StatisticalEvaluationEngine.mqh"


//-------------------------------------------------------------------
// Forward Paper Validation & Evidence Collection (Phase 9)
//-------------------------------------------------------------------
#include "Analytics/ForwardEvidenceTypes.mqh"
#include "Analytics/ForwardEvidenceEngine.mqh"


//-------------------------------------------------------------------
// Diagnostics Engine
//-------------------------------------------------------------------
#include "Diagnostics/DiagnosticsEngine.mqh"


//-------------------------------------------------------------------
// Tests
//-------------------------------------------------------------------
#include "Tests/TestRunner.mqh"
#include "Tests/Phase3Tests.mqh"
#include "Tests/Phase4Tests.mqh"
#include "Tests/Phase5Tests.mqh"
#include "Tests/Phase6Tests.mqh"
#include "Tests/Phase7Tests.mqh"
#include "Tests/Phase8Tests.mqh"
#include "Tests/Phase9Tests.mqh"
#include "Tests/Phase10Tests.mqh"


//+------------------------------------------------------------------+
//| Global runtime objects                                           |
//+------------------------------------------------------------------+

CConfig g_config;


CLogger g_logger(
   g_config.logging_level
);


CRuntimeState g_runtime_state;


CRuntimeValidator g_runtime_validator(
   &g_logger
);


CEventScheduler g_event_scheduler(
   &g_logger,
   g_config.diagnostic_interval_sec,
   100,
   500
);


CCapabilities g_capabilities;


CSymbolUniverseManager g_universe_manager(
   &g_logger
);


CMarketStateCache g_market_cache;


CBarDataManager g_bar_manager(
   &g_logger
);


CMarketDataEngine g_market_engine(
   &g_logger,
   &g_universe_manager,
   &g_bar_manager,
   &g_market_cache
);


CExecutionGuard g_execution_guard(
   &g_logger,
   &g_capabilities,
   &g_runtime_state
);


CExecutionValidator g_execution_validator(
   &g_logger
);


COrderCheckEngine g_order_check_engine(
   &g_logger
);


CRiskEngine g_risk_engine(
   &g_logger
);


CPositionSizer g_position_sizer(
   &g_logger
);


CExecutionRequestBuilder g_request_builder(
   &g_logger,
   &g_order_check_engine,
   &g_market_cache
);


CExecutionPipeline g_execution_pipeline(
   &g_logger,
   &g_risk_engine,
   &g_position_sizer,
   &g_execution_validator,
   &g_request_builder,
   &g_order_check_engine,
   &g_execution_guard
);


CDiagnosticsEngine g_diagnostics(
   &g_logger
);


CMarketFeatureEngine g_feature_engine(
   &g_logger,
   &g_universe_manager,
   &g_bar_manager,
   &g_market_cache
);


CMarketRegimeEngine g_regime_engine(
   &g_logger
);


CSignalEngine g_signal_engine(
   &g_logger
);


CMarketIntelligenceEngine g_intelligence(
   &g_logger,
   &g_feature_engine,
   &g_regime_engine,
   &g_signal_engine,
   &g_universe_manager,
   &g_market_cache,
   &g_bar_manager
);


CStrategyDecisionEngine g_strategy_engine(
   &g_logger,
   &g_intelligence,
   &g_universe_manager
);


CTradePlanner g_trade_planner(
   &g_logger,
   &g_risk_engine,
   &g_position_sizer,
   &g_intelligence,
   &g_universe_manager,
   &g_market_cache
);


CPerformanceEngine g_performance_engine(
   &g_logger
);


CPaperTradeStorage g_storage(
   &g_logger,
   g_config.persistence_directory,
   g_config.storage_schema_version,
   g_config.persistence_enabled
);


CHistoricalAnalyticsEngine g_historical_analytics(
   &g_logger,
   g_config.min_performance_sample
);


CPaperTradingEngine g_paper_engine(
   &g_logger,
   &g_performance_engine,
   &g_universe_manager,
   &g_storage
);


CStatisticalEvaluationEngine g_statistical_evaluation(
   &g_logger
);

SPhase8EvaluationResult g_evaluation_result;


CForwardEvidenceEngine g_forward_evidence(
   &g_logger,
   &g_storage
);


//+------------------------------------------------------------------+
//| Find first available broker symbol                               |
//+------------------------------------------------------------------+
string GetFirstAvailableSymbol()
{
   int symbol_count =
      g_universe_manager.GetSymbolCount();


   for(
      int i = 0;
      i < symbol_count;
      i++
   )
   {
      if(!g_universe_manager.IsAvailable(i))
         continue;


      string symbol =
         g_universe_manager.GetBrokerSymbol(i);


      if(symbol != "")
         return symbol;
   }


   return "";
}


//+------------------------------------------------------------------+
//| Phase 2E risk + sizing dry-run                                  |
//|                                                                  |
//| This function NEVER sends an order.                              |
//+------------------------------------------------------------------+
bool RunRiskSizingDryRun()
{
   g_logger.Log(
      LOG_LEVEL_INFO,
      "RiskEngine",
      "PHASE_2E_START",
      "Starting Phase 2E risk and position-sizing dry-run."
   );


   //----------------------------------------------------------------
   // Find a live broker symbol.
   //----------------------------------------------------------------
   string symbol =
      GetFirstAvailableSymbol();


   if(symbol == "")
   {
      g_logger.Log(
         LOG_LEVEL_ERROR,
         "RiskEngine",
         "PHASE_2E_FAILED",
         "No available broker symbol exists."
      );

      return false;
   }


   //----------------------------------------------------------------
   // Get live price.
   //----------------------------------------------------------------
   MqlTick tick;


   if(
      !SymbolInfoTick(
         symbol,
         tick
      )
      ||
      tick.ask <= 0.0
   )
   {
      g_logger.Log(
         LOG_LEVEL_ERROR,
         "RiskEngine",
         "PHASE_2E_FAILED",
         StringFormat(
            "Unable to obtain a valid ask price for %s.",
            symbol
         )
      );

      return false;
   }


   //----------------------------------------------------------------
   // Point size.
   //----------------------------------------------------------------
   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   if(point <= 0.0)
   {
      g_logger.Log(
         LOG_LEVEL_ERROR,
         "RiskEngine",
         "PHASE_2E_FAILED",
         StringFormat(
            "Invalid point size for %s.",
            symbol
         )
      );

      return false;
   }


   //----------------------------------------------------------------
   // Digits.
   //----------------------------------------------------------------
   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );


   //----------------------------------------------------------------
   // Synthetic entry.
   //----------------------------------------------------------------
   double entry =
      NormalizeDouble(
         tick.ask,
         digits
      );


   //----------------------------------------------------------------
   // Synthetic stop.
   //
   // This is ONLY for infrastructure testing.
   // Strategy-generated stops will replace it later.
   //----------------------------------------------------------------
   double stop_distance_points =
      500.0;


   double stop_loss =
      NormalizeDouble(
         entry -
         (
            stop_distance_points *
            point
         ),
         digits
      );


   if(
      stop_loss <= 0.0 ||
      stop_loss >= entry
   )
   {
      g_logger.Log(
         LOG_LEVEL_ERROR,
         "RiskEngine",
         "PHASE_2E_FAILED",
         StringFormat(
            "Unable to construct a valid synthetic BUY stop for %s.",
            symbol
         )
      );

      return false;
   }


   //----------------------------------------------------------------
   // Risk calculation.
   //----------------------------------------------------------------
   SATGRiskResult risk_result;


   if(
      !g_risk_engine.Calculate(
         symbol,
         entry,
         stop_loss,
         g_risk_engine.GetDefaultRiskPercent(),
         risk_result
      )
   )
   {
      //----------------------------------------------------------------
      // A broker/account-specific rejection is not automatically a
      // system failure. The risk engine itself completed correctly.
      //----------------------------------------------------------------
      g_logger.Log(
         LOG_LEVEL_NOTICE,
         "RiskEngine",
         "PHASE_2E_RISK_REJECTED",

         StringFormat(
            "Risk engine completed but rejected the test request. Symbol=%s Reason=%s",
            symbol,
            risk_result.reason
         )
      );


      return true;
   }


   //----------------------------------------------------------------
   // Position sizing.
   //----------------------------------------------------------------
   SATGPositionSizeResult size_result;


   if(
      !g_position_sizer.Calculate(
         symbol,
         ATG_DIRECTION_BUY,
         entry,
         stop_loss,
         risk_result,
         size_result
      )
   )
   {
      g_logger.Log(
         LOG_LEVEL_NOTICE,
         "PositionSizer",
         "PHASE_2E_SIZING_REJECTED",

         StringFormat(
            "Position sizing completed but rejected the test request. Symbol=%s Reason=%s",
            symbol,
            size_result.reason
         )
      );


      return true;
   }


   //----------------------------------------------------------------
   // Risk result.
   //----------------------------------------------------------------
   g_logger.Log(
      LOG_LEVEL_INFO,
      "RiskEngine",
      "PHASE_2E_RESULT",

      StringFormat(
         "Symbol=%s | Equity=%.2f | Risk=%.4f%% | RiskMoney=%.2f | Entry=%.*f | SL=%.*f",

         symbol,

         risk_result.equity,

         risk_result.risk_percent,

         risk_result.risk_money,

         digits,

         entry,

         digits,

         stop_loss
      )
   );


   //----------------------------------------------------------------
   // Position-size result.
   //----------------------------------------------------------------
   g_logger.Log(
      LOG_LEVEL_INFO,
      "PositionSizer",
      "PHASE_2E_RESULT",

      StringFormat(
         "Symbol=%s | RawVolume=%.8f | FinalVolume=%.8f | EstimatedLoss=%.2f",

         symbol,

         size_result.raw_volume,

         size_result.normalized_volume,

         size_result.estimated_loss_at_volume
      )
   );


   //----------------------------------------------------------------
   // Complete.
   //----------------------------------------------------------------
   g_logger.Log(
      LOG_LEVEL_INFO,
      "RiskEngine",
      "PHASE_2E_COMPLETE",
      "Risk and position-sizing dry-run completed. Trading remains disabled."
   );


   return true;
}


//+------------------------------------------------------------------+
//| Phase 2F full execution pipeline dry-run                         |
//|                                                                  |
//| This function NEVER sends an order.                              |
//| Runs a trade intent through the complete execution pipeline:     |
//|   Trade Intent                                                   |
//|   -> Risk                                                        |
//|   -> Position Sizing                                             |
//|   -> Validation                                                  |
//|   -> Request Builder                                             |
//|   -> OrderCheck                                                  |
//|   -> Reconciliation                                              |
//|   -> Execution Guard                                             |
//|   -> REJECTED: ATG_REJECT_EXECUTION_DISABLED                     |
//+------------------------------------------------------------------+
bool RunExecutionPipelineDryRun()
{
   g_logger.Log(
      LOG_LEVEL_INFO,
      "Pipeline",
      "PHASE_2F_START",
      "Starting Phase 2F full execution pipeline dry-run."
   );


   //----------------------------------------------------------------
   // Find a live broker symbol.
   //----------------------------------------------------------------
   string symbol =
      GetFirstAvailableSymbol();

   if(symbol == "")
   {
      g_logger.Log(
         LOG_LEVEL_ERROR,
         "Pipeline",
         "PHASE_2F_FAILED",
         "No available broker symbol exists."
      );

      return false;
   }


   //----------------------------------------------------------------
   // Get live price.
   //----------------------------------------------------------------
   MqlTick tick;

   if(
      !SymbolInfoTick(
         symbol,
         tick
      )
      ||
      tick.ask <= 0.0
   )
   {
      g_logger.Log(
         LOG_LEVEL_ERROR,
         "Pipeline",
         "PHASE_2F_FAILED",
         StringFormat(
            "Unable to obtain a valid ask price for %s.",
            symbol
         )
      );

      return false;
   }


   //----------------------------------------------------------------
   // Point size and digits.
   //----------------------------------------------------------------
   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   if(point <= 0.0)
   {
      g_logger.Log(
         LOG_LEVEL_ERROR,
         "Pipeline",
         "PHASE_2F_FAILED",
         StringFormat(
            "Invalid point size for %s.",
            symbol
         )
      );

      return false;
   }


   //----------------------------------------------------------------
   // Synthetic entry and protective levels.
   //----------------------------------------------------------------
   double entry =
      NormalizeDouble(
         tick.ask,
         digits
      );

   double stop_loss =
      NormalizeDouble(
         entry -
         (
            500.0 *
            point
         ),
         digits
      );

   double take_profit =
      NormalizeDouble(
         entry +
         (
            1000.0 *
            point
         ),
         digits
      );


   //----------------------------------------------------------------
   // Trade intent (pre-set to minimum volume 0.01 so full pipeline
   // through RequestBuilder, OrderCheck, Reconciliation and ExecutionGuard
   // can be verified on small-account paper equity scale).
   //----------------------------------------------------------------
   SATGTradeIntent intent;
   intent.request_id        = 4000001;
   intent.created_time      = TimeCurrent();
   intent.symbol            = symbol;
   intent.direction         = ATG_DIRECTION_BUY;
   intent.volume            = 0.01;
   intent.requested_price   = entry;
   intent.stop_loss         = stop_loss;
   intent.take_profit       = take_profit;
   intent.risk_percent      = g_risk_engine.GetDefaultRiskPercent();
   intent.signal_confidence = 1.0;
   intent.signal_source     = "PHASE_2F_PIPELINE_TEST";
   intent.strategy_id       = "PIPELINE_TEST";
   intent.comment           = "ATG_PHASE_2F";


   //----------------------------------------------------------------
   // Execute pipeline (Phase 2F).
   //----------------------------------------------------------------
   SExecutionReconciliation recon =
      g_execution_pipeline.ProcessIntent(
         intent
      );

   if(!recon.pipeline_completed)
   {
      g_logger.Log(
         LOG_LEVEL_ERROR,
         "Pipeline",
         "PHASE_2F_FAILED",
         "Execution pipeline did not complete."
      );

      return false;
   }


   //----------------------------------------------------------------
   // Safety barrier verification:
   // Trading capability is disabled, so Execution Guard MUST reject.
   //----------------------------------------------------------------
   if(
      recon.final_state != ATG_EXECUTION_REJECTED ||
      recon.final_reject_reason != ATG_REJECT_EXECUTION_DISABLED
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Pipeline",
         "SAFETY_VIOLATION",
         StringFormat(
            "Pipeline was not blocked by Execution Guard as required! State=%d Reason=%d",
            recon.final_state,
            recon.final_reject_reason
         )
      );

      return false;
   }


   g_logger.Log(
      LOG_LEVEL_INFO,
      "Pipeline",
      "PHASE_2F_COMPLETE",
      StringFormat(
         "Phase 2F execution pipeline dry-run completed successfully. Safety verified: REJECTED with ATG_REJECT_EXECUTION_DISABLED. Reconciled RequestID=%I64u | Symbol=%s | Volume=%.4f | BrokerRetcode=%u",
         recon.request_id,
         recon.intent_symbol,
         recon.built_request.normalized_volume,
         recon.order_check_result.retcode
      )
   );

   return true;
}


//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   //----------------------------------------------------------------
   // Initialization banner.
   //----------------------------------------------------------------
   g_logger.Log(
      LOG_LEVEL_INFO,
      "Core",
      "INIT_START",
      "Starting ATG Trading Engine Phase 2F Initialization."
   );


   //----------------------------------------------------------------
   // HARD SAFETY GATE
   //----------------------------------------------------------------
   if(
      g_capabilities.can_trade
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Security",
         "SAFETY_VIOLATION",
         "Trading capability is enabled during Phase 2E. Initialization halted."
      );


      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Runtime validation.
   //----------------------------------------------------------------
   if(
      !g_runtime_validator.Validate(
         g_runtime_state
      )
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "INIT_FAILED",
         "Runtime environment validation failed."
      );


      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Symbol universe.
   //----------------------------------------------------------------
   g_universe_manager.Initialize(
      g_config.symbol_universe
   );


   g_universe_manager.ValidateUniverse();


   //----------------------------------------------------------------
   // Bar manager.
   //----------------------------------------------------------------
   if(
      !g_bar_manager.Initialize(
         g_config.enabled_timeframes
      )
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "INIT_FAILED",
         "Bar-data manager initialization failed."
      );


      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Market-data engine.
   //----------------------------------------------------------------
   if(
      !g_market_engine.Initialize()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "INIT_FAILED",
         "Market-data engine initialization failed."
      );


      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Timer.
   //----------------------------------------------------------------
   if(
      !EventSetMillisecondTimer(
         g_config.timer_interval_ms
      )
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "INIT_FAILED",
         "Failed to initialize high-resolution timer."
      );


      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Foundation tests.
   //----------------------------------------------------------------
   CTestRunner test_runner(
      &g_logger
   );


   if(
      !test_runner.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "TEST_FAILED",
         "Foundation tests failed."
      );


      EventKillTimer();


      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Phase 3 Market Intelligence Tests
   //----------------------------------------------------------------
   CPhase3Tests phase3_tests(
      &g_logger
   );

   if(
      !phase3_tests.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "PHASE_3_TESTS_FAILED",
         "Phase 3 Market Intelligence tests failed."
      );

      EventKillTimer();

      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Phase 4 Strategy Decision Engine Tests
   //----------------------------------------------------------------
   CPhase4Tests phase4_tests(
      &g_logger
   );

   if(
      !phase4_tests.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "PHASE_4_TESTS_FAILED",
         "Phase 4 Strategy Decision tests failed."
      );

      EventKillTimer();

      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Phase 5 Trade Planning Engine Tests
   //----------------------------------------------------------------
   CPhase5Tests phase5_tests(
      &g_logger
   );

   if(
      !phase5_tests.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "PHASE_5_TESTS_FAILED",
         "Phase 5 Trade Planning tests failed."
      );

      EventKillTimer();

      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Phase 6 Paper Trading & Performance Tests
   //----------------------------------------------------------------
   CPhase6Tests phase6_tests(
      &g_logger
   );

   if(
      !phase6_tests.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "PHASE_6_TESTS_FAILED",
         "Phase 6 Paper Trading & Performance tests failed."
      );

      EventKillTimer();

      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Phase 7 Persistent Paper Trading & Analytics Tests
   //----------------------------------------------------------------
   CPhase7Tests phase7_tests(
      &g_logger
   );

   if(
      !phase7_tests.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "PHASE_7_TESTS_FAILED",
         "Phase 7 Persistent Paper Trading & Analytics tests failed."
      );

      EventKillTimer();

      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Phase 8 Extended Paper Validation & Statistical Evaluation Tests
   //----------------------------------------------------------------
   CPhase8Tests phase8_tests(
      &g_logger
   );

   if(
      !phase8_tests.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "PHASE_8_TESTS_FAILED",
         "Phase 8 Statistical Evaluation tests failed."
      );

      EventKillTimer();

      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Phase 9 Forward Paper Validation & Evidence Tests
   //----------------------------------------------------------------
   CPhase9Tests phase9_tests(
      &g_logger
   );

   if(
      !phase9_tests.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "PHASE_9_TESTS_FAILED",
         "Phase 9 Forward Paper Validation tests failed."
      );

      EventKillTimer();

      return INIT_FAILED;
   }

   //----------------------------------------------------------------
   // Phase 10 Forward Evidence Accumulation & Validation Tests
   //----------------------------------------------------------------
   CPhase10Tests phase10_tests(
      &g_logger
   );

   if(
      !phase10_tests.RunAllTests()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Core",
         "PHASE_10_TESTS_FAILED",
         "Phase 10 Forward Evidence Accumulation tests failed."
      );

      EventKillTimer();

      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Runtime state.
   //----------------------------------------------------------------
   g_runtime_state.initialized =
      true;


   g_runtime_state.mode =
      MODE_MONITOR_ONLY;


   g_runtime_state.safe_state =
      true;


   //----------------------------------------------------------------
   // Verify execution guard is still hard-locked.
   //----------------------------------------------------------------
   SATGTradeIntent safety_intent;


   ZeroMemory(
      safety_intent
   );


   safety_intent.request_id =
      3000001;


   safety_intent.created_time =
      TimeCurrent();


   safety_intent.symbol =
      GetFirstAvailableSymbol();


   safety_intent.direction =
      ATG_DIRECTION_BUY;


   safety_intent.volume =
      0.01;


   safety_intent.requested_price =
      0.0;


   safety_intent.stop_loss =
      0.0;


   safety_intent.take_profit =
      0.0;


   safety_intent.risk_percent =
      0.0;


   safety_intent.signal_confidence =
      0.0;


   safety_intent.signal_source =
      "PHASE_2E_SAFETY_TEST";


   safety_intent.strategy_id =
      "SAFETY_TEST";


   bool guard_result =
      g_execution_guard.Validate(
         safety_intent
      );


   if(
      guard_result ||
      safety_intent.rejection_reason !=
      ATG_REJECT_EXECUTION_DISABLED
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Security",
         "SAFETY_TEST_FAILED",

         StringFormat(
            "Execution guard did not reject the test request correctly. Reason=%d",
            safety_intent.rejection_reason
         )
      );


      EventKillTimer();


      return INIT_FAILED;
   }


   g_logger.Log(
      LOG_LEVEL_INFO,
      "ExecutionGuard",
      "SAFETY_TEST_PASSED",
      "Trade request correctly rejected because trading capability is disabled."
   );


   //----------------------------------------------------------------
   // Phase 2E risk/position sizing dry-run.
   //----------------------------------------------------------------
   if(
      !RunRiskSizingDryRun()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "RiskEngine",
         "PHASE_2E_TEST_FAILED",
         "Risk/position-sizing infrastructure test failed."
      );


      EventKillTimer();


      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Phase 2F full execution pipeline dry-run.
   //----------------------------------------------------------------
   if(
      !RunExecutionPipelineDryRun()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Pipeline",
         "PHASE_2F_TEST_FAILED",
         "Full execution pipeline infrastructure test failed."
      );


      EventKillTimer();


      return INIT_FAILED;
   }


   //----------------------------------------------------------------
   // Initialize Phase 3 Market Intelligence Engine
   //----------------------------------------------------------------
   if(
      !g_intelligence.Initialize()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "Intelligence",
         "INIT_FAILED",
         "Market Intelligence Engine failed to initialize."
      );

      EventKillTimer();

      return INIT_FAILED;
   }

   // Run initial multi-timeframe analysis across universe
   g_intelligence.AnalyzeAll(true);


   //----------------------------------------------------------------
   // Initialize Phase 4 Strategy Decision Engine
   //----------------------------------------------------------------
   if(
      !g_strategy_engine.Initialize()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "StrategyEngine",
         "INIT_FAILED",
         "Strategy Decision Engine failed to initialize."
      );

      EventKillTimer();

      return INIT_FAILED;
   }

   // Run initial strategy evaluation across universe
   g_strategy_engine.EvaluateAll(true);


   //----------------------------------------------------------------
   // Initialize Phase 5 Trade Planning Layer
   //----------------------------------------------------------------
   STradePlannerConfig planner_cfg;
   planner_cfg.risk_percent         = g_config.risk_percent;
   planner_cfg.min_reward_risk      = g_config.min_reward_risk;
   planner_cfg.sl_atr_multiplier    = g_config.sl_atr_multiplier;
   planner_cfg.tp_rr_multiplier     = g_config.tp_rr_multiplier;
   planner_cfg.max_spread_tolerance = g_config.max_spread_tolerance;
   planner_cfg.plan_expiry_sec      = g_config.plan_expiry_sec;
   planner_cfg.entry_buffer_points  = g_config.entry_buffer_points;
   g_trade_planner.SetConfig(planner_cfg);

   // Configure Simulation Equity for Small-Account Forward Validation ($10.00)
   g_risk_engine.SetSimulationEquity(g_config.initial_paper_equity);
   g_risk_engine.SetUseSimulationEquity(true);
   g_trade_planner.SetForwardEvidenceEngine(&g_forward_evidence);

   if(
      !g_trade_planner.Initialize()
   )
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "TradePlanner",
         "INIT_FAILED",
         "Trade Planning Engine failed to initialize."
      );

      EventKillTimer();

      return INIT_FAILED;
   }

   // Run initial trade plan evaluation across universe
   g_trade_planner.ProcessOnBar(g_strategy_engine, true);


   //----------------------------------------------------------------
   // Initialize Phase 6 Paper Trading & Performance Engine
   //----------------------------------------------------------------
   g_performance_engine.SetLogger(&g_logger);
   g_performance_engine.SetInitialEquity(g_config.initial_paper_equity);
   g_performance_engine.SetMinSampleSize(g_config.min_performance_sample);

   g_paper_engine.SetLogger(&g_logger);
   g_paper_engine.SetPerformanceEngine(&g_performance_engine);
   g_paper_engine.SetUniverseManager(&g_universe_manager);
   g_paper_engine.SetEnabled(g_config.paper_trading_enabled);
   g_paper_engine.SetSameBarPolicy(g_config.same_bar_policy);
   g_paper_engine.SetHistoricalAnalyticsEngine(&g_historical_analytics);
   g_paper_engine.SetForwardEvidenceEngine(&g_forward_evidence);

   if(!g_paper_engine.Initialize())
   {
      g_logger.Log(
         LOG_LEVEL_CRITICAL,
         "PaperTradingEngine",
         "INIT_FAILED",
         "Paper Trading Engine failed to initialize."
      );

      EventKillTimer();

      return INIT_FAILED;
   }

   // Run initial paper trade evaluation across universe
   g_paper_engine.ProcessOnBar(g_trade_planner, g_bar_manager);


   //----------------------------------------------------------------
   // Initialize Phase 7 Historical Analytics Layer
   //----------------------------------------------------------------
   if(g_config.historical_analytics_enabled && g_config.persistence_enabled)
   {
      g_historical_analytics.Initialize();
      SPaperTrade closed_trades[];
      int closed_count = g_storage.LoadClosedTrades(closed_trades);
      if(closed_count > 0)
      {
         g_historical_analytics.RebuildFromHistory(closed_trades, g_config.initial_paper_equity);
         g_performance_engine.RebuildFromHistory(closed_trades);
      }
   }


   //----------------------------------------------------------------
   // Initialize Phase 8 Statistical Evaluation Layer
   //----------------------------------------------------------------
   if(g_config.statistical_evaluation_enabled && g_config.persistence_enabled)
   {
      SPaperTrade closed_trades[];
      int closed_count = g_storage.LoadClosedTrades(closed_trades);
      if(closed_count > 0)
      {
         g_statistical_evaluation.RunFullEvaluation(closed_trades, g_evaluation_result,
            g_config.initial_paper_equity, g_config.monte_carlo_runs);
      }
   }


   //----------------------------------------------------------------
   // Initialize Phase 9 Forward Evidence Layer
   //----------------------------------------------------------------
   if(g_config.forward_validation_enabled && g_config.persistence_enabled)
   {
      g_forward_evidence.Initialize(g_config, g_config.active_cohort_id);
      g_forward_evidence.RecordEaRestart();
      SPaperTrade closed_trades[];
      int closed_count = g_storage.LoadClosedTrades(closed_trades);
      if(closed_count > 0)
      {
         g_forward_evidence.RebuildFromHistory(closed_trades);
      }
   }


   //----------------------------------------------------------------
   // Initial diagnostics.
   //----------------------------------------------------------------
   g_diagnostics.RunDiagnostics(
      g_runtime_state,
      g_universe_manager,
      g_market_cache,
      g_config.ea_version,
      &g_performance_engine,
      &g_historical_analytics,
      &g_storage,
      &g_statistical_evaluation,
      &g_forward_evidence
   );


   //----------------------------------------------------------------
   // Final initialization.
   //----------------------------------------------------------------
   g_logger.Log(
      LOG_LEVEL_INFO,
      "Core",
      "INIT_SUCCESS",
      "ATG Trading Engine initialized successfully in Phase 10 MONITOR_ONLY mode (Forward Evidence Accumulation, Monitoring & Validation Active)."
   );


   return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(
   const int reason
)
{
   EventKillTimer();


   g_logger.Log(
      LOG_LEVEL_INFO,
      "Core",
      "SHUTDOWN",

      StringFormat(
         "ATG Trading Engine shutting down. Reason: %d",
         reason
      )
   );
}


//+------------------------------------------------------------------+
//| Tick event                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   // Multi-symbol processing remains synchronized through OnTimer.
}


//+------------------------------------------------------------------+
//| Timer event                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(
      !g_runtime_state.initialized
   )
      return;


   uint start_time =
      GetTickCount();


   //----------------------------------------------------------------
   // Fast market-data processing.
   //----------------------------------------------------------------
   if(
      g_event_scheduler.ShouldRunFast()
   )
   {
      g_market_engine.ProcessTicks(
         g_runtime_state
      );
   }


   //----------------------------------------------------------------
   // Multi-timeframe bar & market intelligence processing.
   //----------------------------------------------------------------
   if(
      g_event_scheduler.ShouldRunBars()
   )
   {
      g_market_engine.ProcessBars();
      g_intelligence.ProcessOnBar();
      g_strategy_engine.ProcessOnBar();
      g_trade_planner.ProcessOnBar(g_strategy_engine);
      g_paper_engine.ProcessOnBar(g_trade_planner, g_bar_manager);
   }


   //----------------------------------------------------------------
   // Periodic diagnostics.
   //----------------------------------------------------------------
   if(
      g_event_scheduler.ShouldRunPeriodic()
   )
   {
      g_diagnostics.RunDiagnostics(
         g_runtime_state,
         g_universe_manager,
         g_market_cache,
         g_config.ea_version,
         &g_performance_engine,
         &g_historical_analytics,
         &g_storage,
         &g_statistical_evaluation,
         &g_forward_evidence
      );

      // Check and generate periodic forward snapshots if due
      if(g_config.forward_validation_enabled)
      {
         g_forward_evidence.CheckPeriodicSnapshots(TimeCurrent());
      }
   }


   //----------------------------------------------------------------
   // Performance monitoring.
   //----------------------------------------------------------------
   uint elapsed =
      GetTickCount() -
      start_time;


   if(
      elapsed > 50
   )
   {
      g_logger.Log(
         LOG_LEVEL_WARNING,
         "Performance",
         "TIMER_SLOW",

         StringFormat(
            "OnTimer execution took %d ms",
            elapsed
         )
      );
   }
}


//+------------------------------------------------------------------+