//+------------------------------------------------------------------+
//| RunPhase8TestsScript.mq5                                         |
//| NeuroPip - Standalone Phase 8 Test Runner Script       |
//| Extended Paper Validation & Statistical Evaluation Test Runner   |
//+------------------------------------------------------------------+
#property copyright "NextGen Technologies"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "../Diagnostics/Logger.mqh"
#include "Phase3Tests.mqh"
#include "Phase4Tests.mqh"
#include "Phase5Tests.mqh"
#include "Phase6Tests.mqh"
#include "Phase7Tests.mqh"
#include "Phase8Tests.mqh"

void OnStart()
{
   CLogger logger(LOG_LEVEL_DEBUG);
   Print("=== RUNNING NEUROPIP ENGINE PHASE 3-8 TEST SUITES ===");

   CPhase3Tests p3(&logger);
   bool p3_ok = p3.RunAllTests();
   PrintFormat("Phase 3 Tests Result: %s", p3_ok ? "PASS" : "FAIL");

   CPhase4Tests p4(&logger);
   bool p4_ok = p4.RunAllTests();
   PrintFormat("Phase 4 Tests Result: %s", p4_ok ? "PASS" : "FAIL");

   CPhase5Tests p5(&logger);
   bool p5_ok = p5.RunAllTests();
   PrintFormat("Phase 5 Tests Result: %s", p5_ok ? "PASS" : "FAIL");

   CPhase6Tests p6(&logger);
   bool p6_ok = p6.RunAllTests();
   PrintFormat("Phase 6 Tests Result: %s", p6_ok ? "PASS" : "FAIL");

   CPhase7Tests p7(&logger);
   bool p7_ok = p7.RunAllTests();
   PrintFormat("Phase 7 Tests Result: %s", p7_ok ? "PASS" : "FAIL");

   CPhase8Tests p8(&logger);
   bool p8_ok = p8.RunAllTests();
   PrintFormat("Phase 8 Tests Result: %s", p8_ok ? "PASS" : "FAIL");

   if(p3_ok && p4_ok && p5_ok && p6_ok && p7_ok && p8_ok)
   {
      Print("=== ALL SUITES (PHASES 3, 4, 5, 6, 7, 8) PASSED SUCCESSFULLY ===");
   }
   else
   {
      Print("=== TEST SUITE FAILURES DETECTED ===");
   }
}
