//+------------------------------------------------------------------+
//| VerifyExperimentalStrategiesScript.mq5                           |
//| NeuroPip - Experimental Strategies Compilation & Verification    |
//| Validates compilation of Track B candidates without altering     |
//| frozen Track A baseline                                          |
//+------------------------------------------------------------------+
#property copyright "NextGen Technologies"
#property link      ""
#property version   "1.00"

#include "../Diagnostics/Logger.mqh"
#include "../Strategy/TrendContinuationStrategy.mqh"
#include "../Strategy/AdaptiveTrendStrategy.mqh"
#include "../Strategy/PullbackContinuationStrategy.mqh"
#include "../Strategy/MomentumBreakoutStrategy.mqh"

void OnStart()
{
   CLogger logger(LOG_LEVEL_INFO);
   Print("=== VERIFYING TRACK B EXPERIMENTAL STRATEGIES COMPILATION ===");

   // Baseline (Track A)
   CTrendContinuationStrategy strat_base(&logger);
   PrintFormat("Track A Baseline Strategy ID: %s", strat_base.GetParameters().strategy_id);

   // Candidate 1 (Track B)
   CAdaptiveTrendStrategy strat_cand1(&logger);
   PrintFormat("Track B Candidate 1 Strategy ID: %s", strat_cand1.GetParameters().strategy_id);

   // Candidate 2 (Track B)
   CPullbackContinuationStrategy strat_cand2(&logger);
   PrintFormat("Track B Candidate 2 Strategy ID: %s", strat_cand2.GetParameters().strategy_id);

   // Candidate 3 (Track B)
   CMomentumBreakoutStrategy strat_cand3(&logger);
   PrintFormat("Track B Candidate 3 Strategy ID: %s", strat_cand3.GetParameters().strategy_id);

   Print("=== COMPILATION & INSTANTIATION TEST PASSED 100% ===");
}
