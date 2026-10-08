//+------------------------------------------------------------------+
//| BarDataManager.mqh                                               |
//| ATG Trading Engine - Phase 1C                                     |
//| Reliable Multi-Timeframe Closed-Bar Detection                    |
//| MONITOR_ONLY - No trading operations                              |
//+------------------------------------------------------------------+

#ifndef ATG_BAR_DATA_MANAGER_MQH
#define ATG_BAR_DATA_MANAGER_MQH

#include "../Diagnostics/Logger.mqh"

//+------------------------------------------------------------------+
//| Bar tracker state                                                |
//+------------------------------------------------------------------+
struct SBarTracker
{
   string          symbol;
   ENUM_TIMEFRAMES timeframe;

   datetime        current_bar_time;
   datetime        previous_bar_time;

   CBarState       latest_bar;

   bool            initialized;
   bool            data_ready;
   bool            new_bar;
};

//+------------------------------------------------------------------+
//| Bar Data Manager                                                  |
//+------------------------------------------------------------------+
class CBarDataManager
{
private:

   CLogger*        m_logger;

   ENUM_TIMEFRAMES m_timeframes[];

   SBarTracker     m_trackers[];

   int             m_symbol_count;

   //+----------------------------------------------------------------+
   //| Convert timeframe to readable text                            |
   //+----------------------------------------------------------------+
   string TimeframeToString(ENUM_TIMEFRAMES timeframe)
   {
      switch(timeframe)
      {
         case PERIOD_M1:
            return "M1";

         case PERIOD_M2:
            return "M2";

         case PERIOD_M3:
            return "M3";

         case PERIOD_M4:
            return "M4";

         case PERIOD_M5:
            return "M5";

         case PERIOD_M6:
            return "M6";

         case PERIOD_M10:
            return "M10";

         case PERIOD_M12:
            return "M12";

         case PERIOD_M15:
            return "M15";

         case PERIOD_M20:
            return "M20";

         case PERIOD_M30:
            return "M30";

         case PERIOD_H1:
            return "H1";

         case PERIOD_H2:
            return "H2";

         case PERIOD_H3:
            return "H3";

         case PERIOD_H4:
            return "H4";

         case PERIOD_H6:
            return "H6";

         case PERIOD_H8:
            return "H8";

         case PERIOD_H12:
            return "H12";

         case PERIOD_D1:
            return "D1";

         case PERIOD_W1:
            return "W1";

         case PERIOD_MN1:
            return "MN1";
      }

      return "UNKNOWN";
   }

   //+----------------------------------------------------------------+
   //| Find tracker                                                    |
   //+----------------------------------------------------------------+
   int FindTracker(
      string symbol,
      ENUM_TIMEFRAMES timeframe
   )
   {
      for(int i = 0; i < ArraySize(m_trackers); i++)
      {
         if(m_trackers[i].symbol == symbol &&
            m_trackers[i].timeframe == timeframe)
         {
            return i;
         }
      }

      return -1;
   }

   //+----------------------------------------------------------------+
   //| Read latest closed candle                                      |
   //+----------------------------------------------------------------+
   bool ReadLatestClosedBar(int tracker_index)
   {
      if(tracker_index < 0 ||
         tracker_index >= ArraySize(m_trackers))
      {
         return false;
      }

      string symbol =
         m_trackers[tracker_index].symbol;

      ENUM_TIMEFRAMES timeframe =
         m_trackers[tracker_index].timeframe;

      MqlRates rates[];

      ArraySetAsSeries(rates, true);

      ResetLastError();

      int copied =
         CopyRates(
            symbol,
            timeframe,
            1,
            1,
            rates
         );

      if(copied != 1)
      {
         m_trackers[tracker_index].data_ready = false;

         if(m_logger != NULL)
         {
            m_logger.Log(
               LOG_LEVEL_WARNING,
               "BarDataManager",
               "BAR_READ_FAILED",
               StringFormat(
                  "%s %s failed to read closed bar. CopyRates=%d Error=%d",
                  symbol,
                  TimeframeToString(timeframe),
                  copied,
                  GetLastError()
               )
            );
         }

         return false;
      }

      m_trackers[tracker_index].latest_bar.time =
         rates[0].time;

      m_trackers[tracker_index].latest_bar.open =
         rates[0].open;

      m_trackers[tracker_index].latest_bar.high =
         rates[0].high;

      m_trackers[tracker_index].latest_bar.low =
         rates[0].low;

      m_trackers[tracker_index].latest_bar.close =
         rates[0].close;

      m_trackers[tracker_index].latest_bar.tick_volume =
         rates[0].tick_volume;

      m_trackers[tracker_index].latest_bar.real_volume =
         rates[0].real_volume;

      m_trackers[tracker_index].latest_bar.spread =
         rates[0].spread;

      m_trackers[tracker_index].data_ready = true;

      return true;
   }

   //+----------------------------------------------------------------+
   //| Synchronize market history                                    |
   //+----------------------------------------------------------------+
   bool SynchronizeHistory(
      string symbol,
      ENUM_TIMEFRAMES timeframe
   )
   {
      if(symbol == "")
         return false;

      ResetLastError();

      if(!SymbolSelect(symbol, true))
      {
         if(m_logger != NULL)
         {
            m_logger.Log(
               LOG_LEVEL_WARNING,
               "BarDataManager",
               "SYMBOL_SELECT_FAILED",
               StringFormat(
                  "%s %s could not be selected. Error=%d",
                  symbol,
                  TimeframeToString(timeframe),
                  GetLastError()
               )
            );
         }

         return false;
      }

      int bars =
         Bars(
            symbol,
            timeframe
         );

      if(bars <= 0)
      {
         if(m_logger != NULL)
         {
            m_logger.Log(
               LOG_LEVEL_WARNING,
               "BarDataManager",
               "HISTORY_NOT_READY",
               StringFormat(
                  "%s %s history is not ready. Bars=%d Error=%d",
                  symbol,
                  TimeframeToString(timeframe),
                  bars,
                  GetLastError()
               )
            );
         }

         return false;
      }

      MqlRates preload[];

      ArraySetAsSeries(preload, true);

      ResetLastError();

      int copied =
         CopyRates(
            symbol,
            timeframe,
            0,
            3,
            preload
         );

      if(copied < 2)
      {
         if(m_logger != NULL)
         {
            m_logger.Log(
               LOG_LEVEL_WARNING,
               "BarDataManager",
               "HISTORY_SYNC_INCOMPLETE",
               StringFormat(
                  "%s %s history synchronization incomplete. Copied=%d Error=%d",
                  symbol,
                  TimeframeToString(timeframe),
                  copied,
                  GetLastError()
               )
            );
         }

         return false;
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Detect closed-bar transition                                  |
   //+----------------------------------------------------------------+
   bool UpdateTracker(int tracker_index)
   {
      if(tracker_index < 0 ||
         tracker_index >= ArraySize(m_trackers))
      {
         return false;
      }

      string symbol =
         m_trackers[tracker_index].symbol;

      ENUM_TIMEFRAMES timeframe =
         m_trackers[tracker_index].timeframe;

      MqlRates rates[];

      ArraySetAsSeries(rates, true);

      ResetLastError();

      int copied =
         CopyRates(
            symbol,
            timeframe,
            1,
            1,
            rates
         );

      if(copied != 1)
      {
         m_trackers[tracker_index].data_ready = false;

         return false;
      }

      datetime closed_bar_time =
         rates[0].time;

      if(closed_bar_time <= 0)
      {
         m_trackers[tracker_index].data_ready = false;

         return false;
      }

      // New-bar flag is transient and represents this processing cycle.
      m_trackers[tracker_index].new_bar = false;

      // First observation.
      if(!m_trackers[tracker_index].initialized)
      {
         m_trackers[tracker_index].current_bar_time =
            closed_bar_time;

         m_trackers[tracker_index].previous_bar_time =
            0;

         m_trackers[tracker_index].initialized =
            true;

         m_trackers[tracker_index].latest_bar.time =
            rates[0].time;

         m_trackers[tracker_index].latest_bar.open =
            rates[0].open;

         m_trackers[tracker_index].latest_bar.high =
            rates[0].high;

         m_trackers[tracker_index].latest_bar.low =
            rates[0].low;

         m_trackers[tracker_index].latest_bar.close =
            rates[0].close;

         m_trackers[tracker_index].latest_bar.tick_volume =
            rates[0].tick_volume;

         m_trackers[tracker_index].latest_bar.real_volume =
            rates[0].real_volume;

         m_trackers[tracker_index].latest_bar.spread =
            rates[0].spread;

         m_trackers[tracker_index].data_ready =
            true;

         if(m_logger != NULL)
         {
            m_logger.Log(
               LOG_LEVEL_INFO,
               "BarDataManager",
               "BAR_SYNC",
               StringFormat(
                  "%s %s synchronized. Closed bar=%s",
                  symbol,
                  TimeframeToString(timeframe),
                  TimeToString(
                     closed_bar_time,
                     TIME_DATE | TIME_MINUTES
                  )
               )
            );
         }

         return false;
      }

      // No new closed bar.
      if(closed_bar_time ==
         m_trackers[tracker_index].current_bar_time)
      {
         m_trackers[tracker_index].data_ready = true;

         return false;
      }

      // A new closed bar has appeared.
      m_trackers[tracker_index].previous_bar_time =
         m_trackers[tracker_index].current_bar_time;

      m_trackers[tracker_index].current_bar_time =
         closed_bar_time;

      m_trackers[tracker_index].new_bar =
         true;

      m_trackers[tracker_index].latest_bar.time =
         rates[0].time;

      m_trackers[tracker_index].latest_bar.open =
         rates[0].open;

      m_trackers[tracker_index].latest_bar.high =
         rates[0].high;

      m_trackers[tracker_index].latest_bar.low =
         rates[0].low;

      m_trackers[tracker_index].latest_bar.close =
         rates[0].close;

      m_trackers[tracker_index].latest_bar.tick_volume =
         rates[0].tick_volume;

      m_trackers[tracker_index].latest_bar.real_volume =
         rates[0].real_volume;

      m_trackers[tracker_index].latest_bar.spread =
         rates[0].spread;

      m_trackers[tracker_index].data_ready =
         true;

      if(m_logger != NULL)
      {
         m_logger.Log(
            LOG_LEVEL_INFO,
            "BarDataManager",
            "NEW_BAR",
            StringFormat(
               "%s %s new closed bar detected. Bar=%s O=%.5f H=%.5f L=%.5f C=%.5f",
               symbol,
               TimeframeToString(timeframe),
               TimeToString(
                  closed_bar_time,
                  TIME_DATE | TIME_MINUTES
               ),
               rates[0].open,
               rates[0].high,
               rates[0].low,
               rates[0].close
            )
         );
      }

      return true;
   }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CBarDataManager(CLogger* logger)
      : m_logger(logger),
        m_symbol_count(0)
   {
   }

   //+----------------------------------------------------------------+
   //| Initialize timeframe configuration                            |
   //+----------------------------------------------------------------+
   bool Initialize(
      const ENUM_TIMEFRAMES &tfs[]
   )
   {
      int size =
         ArraySize(tfs);

      ArrayResize(
         m_timeframes,
         size
      );

      for(int i = 0; i < size; i++)
      {
         m_timeframes[i] =
            tfs[i];
      }

      ArrayResize(
         m_trackers,
         0
      );

      m_symbol_count = 0;

      if(m_logger != NULL)
      {
         m_logger.Log(
            LOG_LEVEL_INFO,
            "BarDataManager",
            "INIT_SUCCESS",
            StringFormat(
               "Bar manager initialized with %d timeframe(s).",
               size
            )
         );
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Register symbol                                                |
   //+----------------------------------------------------------------+
   bool RegisterSymbol(
      string symbol
   )
   {
      if(symbol == "")
         return false;

      if(ArraySize(m_timeframes) <= 0)
         return false;

      // Prevent duplicate registration.
      for(int i = 0; i < ArraySize(m_trackers); i++)
      {
         if(m_trackers[i].symbol == symbol)
            return true;
      }

      int timeframe_count =
         ArraySize(m_timeframes);

      int old_size =
         ArraySize(m_trackers);

      ArrayResize(
         m_trackers,
         old_size + timeframe_count
      );

      for(int i = 0; i < timeframe_count; i++)
      {
         int index =
            old_size + i;

         m_trackers[index].symbol =
            symbol;

         m_trackers[index].timeframe =
            m_timeframes[i];

         m_trackers[index].current_bar_time =
            0;

         m_trackers[index].previous_bar_time =
            0;

         m_trackers[index].initialized =
            false;

         m_trackers[index].data_ready =
            false;

         m_trackers[index].new_bar =
            false;

         ZeroMemory(
            m_trackers[index].latest_bar
         );
      }

      m_symbol_count++;

      // Preload/synchronize every configured timeframe.
      for(int i = 0; i < timeframe_count; i++)
      {
         SynchronizeHistory(
            symbol,
            m_timeframes[i]
         );
      }

      if(m_logger != NULL)
      {
         m_logger.Log(
            LOG_LEVEL_DEBUG,
            "BarDataManager",
            "SYMBOL_REGISTERED",
            StringFormat(
               "%s registered for %d timeframe(s).",
               symbol,
               timeframe_count
            )
         );
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Process all configured timeframes for a symbol                 |
   //+----------------------------------------------------------------+
   bool ProcessNewBars(
      string symbol
   )
   {
      if(symbol == "")
         return false;

      if(ArraySize(m_timeframes) <= 0)
         return false;

      // Automatically register if necessary.
      if(FindTracker(
            symbol,
            m_timeframes[0]
         ) < 0)
      {
         if(!RegisterSymbol(symbol))
            return false;
      }

      bool any_new_bar = false;

      for(int i = 0;
          i < ArraySize(m_trackers);
          i++)
      {
         if(m_trackers[i].symbol != symbol)
            continue;

         if(UpdateTracker(i))
         {
            any_new_bar = true;
         }
      }

      return any_new_bar;
   }

   //+----------------------------------------------------------------+
   //| Process every registered symbol                               |
   //+----------------------------------------------------------------+
   int ProcessAll()
   {
      int new_bar_count = 0;

      string processed_symbols[];

      int processed_count = 0;

      for(int i = 0;
          i < ArraySize(m_trackers);
          i++)
      {
         string symbol =
            m_trackers[i].symbol;

         bool already_processed =
            false;

         for(int j = 0;
             j < processed_count;
             j++)
         {
            if(processed_symbols[j] == symbol)
            {
               already_processed = true;
               break;
            }
         }

         if(already_processed)
            continue;

         ArrayResize(
            processed_symbols,
            processed_count + 1
         );

         processed_symbols[processed_count] =
            symbol;

         processed_count++;

         if(ProcessNewBars(symbol))
            new_bar_count++;
      }

      return new_bar_count;
   }

   //+----------------------------------------------------------------+
   //| Get latest closed bar                                          |
   //+----------------------------------------------------------------+
   bool GetLatestBar(
      string symbol,
      ENUM_TIMEFRAMES timeframe,
      CBarState &bar
   )
   {
      int index =
         FindTracker(
            symbol,
            timeframe
         );

      if(index < 0)
         return false;

      if(!m_trackers[index].data_ready)
         return false;

      bar =
         m_trackers[index].latest_bar;

      return true;
   }

   //+----------------------------------------------------------------+
   //| Check whether a new bar was detected                           |
   //+----------------------------------------------------------------+
   bool IsNewBar(
      string symbol,
      ENUM_TIMEFRAMES timeframe
   )
   {
      int index =
         FindTracker(
            symbol,
            timeframe
         );

      if(index < 0)
         return false;

      return m_trackers[index].new_bar;
   }

   //+----------------------------------------------------------------+
   //| Get latest closed-bar timestamp                               |
   //+----------------------------------------------------------------+
   datetime GetLatestBarTime(
      string symbol,
      ENUM_TIMEFRAMES timeframe
   )
   {
      int index =
         FindTracker(
            symbol,
            timeframe
         );

      if(index < 0)
         return 0;

      return m_trackers[index].current_bar_time;
   }

   //+----------------------------------------------------------------+
   //| Get configured timeframe count                                |
   //+----------------------------------------------------------------+
   int GetTimeframeCount()
   {
      return ArraySize(
         m_timeframes
      );
   }

   //+----------------------------------------------------------------+
   //| Get registered tracker count                                  |
   //+----------------------------------------------------------------+
   int GetTrackerCount()
   {
      return ArraySize(
         m_trackers
      );
   }

   //+----------------------------------------------------------------+
   //| Reset transient new-bar flags                                 |
   //+----------------------------------------------------------------+
   void ResetNewBarFlags()
   {
      for(int i = 0;
          i < ArraySize(m_trackers);
          i++)
      {
         m_trackers[i].new_bar =
            false;
      }
   }
};

#endif