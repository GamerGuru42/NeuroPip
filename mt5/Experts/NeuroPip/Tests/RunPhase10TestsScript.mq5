//+------------------------------------------------------------------+
//| RunPhase10TestsScript.mq5                                        |
//| ATG Trading Engine - Standalone Phase 10 Test Runner Script      |
//| Forward Evidence Accumulation, Monitoring & Validation Runner    |
//+------------------------------------------------------------------+
#property copyright "ATG"
#property link      ""
#property version   "1.00"

#include "../Diagnostics/Logger.mqh"
#include "Phase3Tests.mqh"
#include "Phase4Tests.mqh"
#include "Phase5Tests.mqh"
#include "Phase6Tests.mqh"
#include "Phase7Tests.mqh"
#include "Phase8Tests.mqh"
#include "Phase9Tests.mqh"
#include "Phase10Tests.mqh"

void OnStart()
{
   CLogger logger(LOG_LEVEL_NOTICE);
   Print("=== RUNNING ATG ENGINE PHASE 3-10 MASTER TEST SUITES ===");

   // Wait up to 10s for terminal to establish broker connection
   int attempts = 0;
   while(!TerminalInfoInteger(TERMINAL_CONNECTED) && attempts < 20)
   {
      Sleep(500);
      attempts++;
   }

   Print(">>> STARTING PHASE 3 SUITE");
   CPhase3Tests p3(&logger);
   bool p3_ok = p3.RunAllTests();
   PrintFormat("Phase 3 Tests Result: %s", p3_ok ? "PASS" : "FAIL");

   Print(">>> STARTING PHASE 4 SUITE");
   CPhase4Tests p4(&logger);
   bool p4_ok = p4.RunAllTests();
   PrintFormat("Phase 4 Tests Result: %s", p4_ok ? "PASS" : "FAIL");

   Print(">>> STARTING PHASE 5 SUITE");
   CPhase5Tests p5(&logger);
   bool p5_ok = p5.RunAllTests();
   PrintFormat("Phase 5 Tests Result: %s", p5_ok ? "PASS" : "FAIL");

   Print(">>> STARTING PHASE 6 SUITE");
   CPhase6Tests p6(&logger);
   bool p6_ok = p6.RunAllTests();
   PrintFormat("Phase 6 Tests Result: %s", p6_ok ? "PASS" : "FAIL");

   Print(">>> STARTING PHASE 7 SUITE");
   CPhase7Tests p7(&logger);
   bool p7_ok = p7.RunAllTests();
   PrintFormat("Phase 7 Tests Result: %s", p7_ok ? "PASS" : "FAIL");

   Print(">>> STARTING PHASE 8 SUITE");
   CPhase8Tests p8(&logger);
   bool p8_ok = p8.RunAllTests();
   PrintFormat("Phase 8 Tests Result: %s", p8_ok ? "PASS" : "FAIL");

   Print(">>> STARTING PHASE 9 SUITE");
   CPhase9Tests p9(&logger);
   bool p9_ok = p9.RunAllTests();
   PrintFormat("Phase 9 Tests Result: %s", p9_ok ? "PASS" : "FAIL");

   Print(">>> STARTING PHASE 10 SUITE");
   CPhase10Tests p10(&logger);
   bool p10_ok = p10.RunAllTests();
   PrintFormat("Phase 10 Tests Result: %s", p10_ok ? "PASS" : "FAIL");

   if(p3_ok && p4_ok && p5_ok && p6_ok && p7_ok && p8_ok && p9_ok && p10_ok)
   {
      Print("=== ALL SUITES (PHASES 3, 4, 5, 6, 7, 8, 9, 10) PASSED SUCCESSFULLY ===");
   }
   else
   {
      Print("=== TEST SUITE FAILURES DETECTED ===");
   }

   // Flush and exit cleanly
   Sleep(2000);
   TerminalClose(0);
}
