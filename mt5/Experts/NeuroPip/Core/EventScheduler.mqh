//+------------------------------------------------------------------+
//| EventScheduler.mqh                                               |
//| NeuroPip - Phase 1C                                    |
//| Deterministic runtime scheduling                                 |
//+------------------------------------------------------------------+
#ifndef ATG_EVENT_SCHEDULER_MQH
#define ATG_EVENT_SCHEDULER_MQH

#include "../Diagnostics/Logger.mqh"

class CEventScheduler
{
private:

   CLogger* m_logger;

   uint m_last_fast_ms;
   uint m_last_bar_ms;
   uint m_last_periodic_ms;

   uint m_fast_interval_ms;
   uint m_bar_interval_ms;
   uint m_periodic_interval_ms;

public:

   int timer_skips;

   CEventScheduler(
      CLogger* logger,
      uint periodic_sec = 60,
      uint fast_interval_ms = 100,
      uint bar_interval_ms = 500
   )
      : m_logger(logger)
   {
      m_fast_interval_ms =
         fast_interval_ms;

      m_bar_interval_ms =
         bar_interval_ms;

      m_periodic_interval_ms =
         periodic_sec * 1000;

      uint now = GetTickCount();

      m_last_fast_ms =
         now;

      m_last_bar_ms =
         now;

      m_last_periodic_ms =
         now;

      timer_skips = 0;
   }

   //+--------------------------------------------------------------+
   //| Fast processing                                               |
   //+--------------------------------------------------------------+
   bool ShouldRunFast()
   {
      uint now = GetTickCount();

      if((uint)(now - m_last_fast_ms) >=
         m_fast_interval_ms)
      {
         m_last_fast_ms = now;
         return true;
      }

      return false;
   }

   //+--------------------------------------------------------------+
   //| Bar processing                                                |
   //+--------------------------------------------------------------+
   bool ShouldRunBars()
   {
      uint now = GetTickCount();

      if((uint)(now - m_last_bar_ms) >=
         m_bar_interval_ms)
      {
         m_last_bar_ms = now;
         return true;
      }

      return false;
   }

   //+--------------------------------------------------------------+
   //| Periodic diagnostics                                          |
   //+--------------------------------------------------------------+
   bool ShouldRunPeriodic()
   {
      uint now = GetTickCount();

      if((uint)(now - m_last_periodic_ms) >=
         m_periodic_interval_ms)
      {
         m_last_periodic_ms = now;
         return true;
      }

      return false;
   }

   //+--------------------------------------------------------------+
   //| Reset scheduler                                               |
   //+--------------------------------------------------------------+
   void Reset()
   {
      uint now = GetTickCount();

      m_last_fast_ms =
         now;

      m_last_bar_ms =
         now;

      m_last_periodic_ms =
         now;

      timer_skips = 0;
   }
};

#endif