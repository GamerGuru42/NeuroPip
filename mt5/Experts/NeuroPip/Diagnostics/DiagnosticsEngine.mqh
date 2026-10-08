//+------------------------------------------------------------------+
//| DiagnosticsEngine.mqh                                            |
//| ATG Trading Engine - Phase 7                                      |
//+------------------------------------------------------------------+
#ifndef ATG_DIAGNOSTICS_ENGINE_MQH
#define ATG_DIAGNOSTICS_ENGINE_MQH

#include "../Core/RuntimeState.mqh"
#include "../MarketData/SymbolUniverseManager.mqh"
#include "../MarketData/MarketStateCache.mqh"
#include "../Simulation/PerformanceEngine.mqh"
#include "../Persistence/HistoricalAnalyticsEngine.mqh"
#include "../Persistence/PaperTradeStorage.mqh"
#include "../Analytics/EvaluationTypes.mqh"
#include "../Analytics/StatisticalEvaluationEngine.mqh"
#include "../Analytics/ForwardEvidenceEngine.mqh"
#include "Logger.mqh"

class CDiagnosticsEngine
{
private:
   CLogger* m_logger;

public:
   CDiagnosticsEngine(CLogger* logger) : m_logger(logger) {}

   void RunDiagnostics(CRuntimeState &state,
                       CSymbolUniverseManager &universe,
                       CMarketStateCache &cache,
                       string version,
                       CPerformanceEngine* performance = NULL,
                       CHistoricalAnalyticsEngine* analytics = NULL,
                       CPaperTradeStorage* storage = NULL,
                       CStatisticalEvaluationEngine* evaluation = NULL,
                       CForwardEvidenceEngine* evidence = NULL)
   {
      string report = "\n=== ATG TRADING ENGINE ===\n";
      report += StringFormat("Version: %s\nPhase: 9 (Forward Paper Validation, Monitoring & Evidence Collection)\nMode: %s\n\n",
         version, state.mode == MODE_MONITOR_ONLY ? "MONITOR_ONLY" : "UNKNOWN");
      report += StringFormat("Terminal: %s\n", state.terminal_connected ? "CONNECTED" : "DISCONNECTED");
      report += StringFormat("Account:  %s\n", state.account_login > 0 ? "CONNECTED" : "DISCONNECTED");
      report += StringFormat("Broker:   %s\n", state.broker);
      report += StringFormat("Server:   %s\n\n", state.server);

      report += "Market Universe:\n";
      for(int i = 0; i < universe.GetSymbolCount(); i++)
      {
         SSymbolInfo info = universe.GetSymbol(i);
         report += StringFormat("%-10s %s\n", info.name, info.available ? "READY" : "UNAVAILABLE");
      }

      report += "\nMarket Intelligence:\nACTIVE (Features / Regime / Signal Foundation)\n";
      report += "Strategy Decision Engine:\nACTIVE (ATG_TREND_CONTINUATION / Multi-Gate Quality Validation / CONFIG FROZEN)\n";
      report += "Trade Planning Engine:\nACTIVE (14-Gate Validation / ATR Stop / RR Target / RiskEngine & PositionSizer)\n";
      report += "Paper Trading Engine:\nACTIVE (Deterministic Fill / Conservative Ambiguity SL / Zero Live Orders)\n";
      report += "Persistent Storage:\nACTIVE (Durable Schema v2 / Atomic Active / Closed History / Snapshot History / Audit Trail)\n";
      report += "Historical Analytics:\nACTIVE (Multi-Period Daily/Weekly/Monthly / Symbol / Strategy / Regime)\n";
      report += "Statistical Evaluation:\nACTIVE (Distribution / OOS / Walk-Forward / Monte Carlo / Robustness)\n";
      report += "Forward Evidence Engine:\nACTIVE (Frozen Config Snapshot / Strict Live Separation / Cohort Tracking / Health Monitor)\n";
      report += "Trading Capability:\nDISABLED - EXECUTION GUARD HARD-LOCKED (can_trade=false)\n";

      if(performance != NULL)
      {
         report += performance.GenerateReport();
      }

      if(analytics != NULL && analytics.GetTotalTrades() > 0)
      {
         report += analytics.GenerateHistoricalReport();
      }

      if(evaluation != NULL && evaluation.GetTotalTrades() > 0)
      {
         report += evaluation.GenerateEvaluationReport();
      }

      if(evidence != NULL)
      {
         report += evidence.GenerateForwardEvidenceReport();
      }

      Print(report);
      state.last_diagnostic_run = TimeCurrent();
   }
};

#endif
