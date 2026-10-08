//+------------------------------------------------------------------+
//| MarketDataEngine.mqh                                             |
//| NeuroPip - Phase 1C                                    |
//| Live Tick + Multi-Timeframe Bar Processing                       |
//| MONITOR_ONLY - No trading operations                             |
//+------------------------------------------------------------------+
#ifndef ATG_MARKET_DATA_ENGINE_MQH
#define ATG_MARKET_DATA_ENGINE_MQH

#include "MarketStateCache.mqh"
#include "SymbolUniverseManager.mqh"
#include "BarDataManager.mqh"
#include "../Diagnostics/Logger.mqh"
#include "../Core/RuntimeState.mqh"

class CMarketDataEngine
{
private:

   CLogger* m_logger;
   CSymbolUniverseManager* m_universe;
   CBarDataManager* m_bar_manager;
   CMarketStateCache* m_cache;

   datetime m_last_health_report;
   int      m_health_report_interval_sec;

   //+----------------------------------------------------------------+
   //| Process live tick for one symbol                              |
   //+----------------------------------------------------------------+
   bool ProcessSymbolTick(int index)
   {
      if(index < 0 ||
         index >= ArraySize(m_cache.symbols))
      {
         return false;
      }

      if(!m_cache.symbols[index].enabled)
         return false;

      string symbol =
         m_cache.symbols[index].symbol;

      MqlTick tick;

      if(!SymbolInfoTick(symbol, tick))
      {
         m_cache.symbols[index].data_health =
            DATA_UNAVAILABLE;

         return false;
      }

      m_cache.symbols[index].bid =
         tick.bid;

      m_cache.symbols[index].ask =
         tick.ask;

      m_cache.symbols[index].last =
         tick.last;

      m_cache.symbols[index].tick_time =
         tick.time;

      m_cache.symbols[index].tick_time_msc =
         tick.time_msc;

      m_cache.symbols[index].tick_flags =
         tick.flags;

      m_cache.symbols[index].spread_price =
         tick.ask - tick.bid;

      if(m_cache.symbols[index].point > 0.0)
      {
         m_cache.symbols[index].spread_points =
            (int)MathRound(
               (tick.ask - tick.bid) /
               m_cache.symbols[index].point
            );
      }
      else
      {
         m_cache.symbols[index].spread_points =
            0;
      }

      m_cache.symbols[index].last_update_time =
         TimeCurrent();

      m_cache.symbols[index].data_health =
         DATA_READY;

      return true;
   }

   //+----------------------------------------------------------------+
   //| Generate market health report                                 |
   //+----------------------------------------------------------------+
   void ReportMarketHealth()
   {
      datetime now =
         TimeCurrent();

      if(m_last_health_report != 0)
      {
         if((now - m_last_health_report) <
            m_health_report_interval_sec)
         {
            return;
         }
      }

      m_last_health_report =
         now;

      int total = 0;
      int healthy = 0;

      for(int i = 0;
          i < ArraySize(m_cache.symbols);
          i++)
      {
         if(!m_cache.symbols[i].enabled)
            continue;

         total++;

         if(m_cache.symbols[i].data_health ==
            DATA_READY)
         {
            healthy++;
         }
      }

      m_logger.Log(
         LOG_LEVEL_INFO,
         "MarketDataEngine",
         "MARKET_HEALTH",
         StringFormat(
            "Live market-data health: %d/%d symbols healthy.",
            healthy,
            total
         )
      );

      for(int i = 0;
          i < ArraySize(m_cache.symbols);
          i++)
      {
         if(!m_cache.symbols[i].enabled)
            continue;

         string health =
            "UNAVAILABLE";

         if(m_cache.symbols[i].data_health ==
            DATA_READY)
         {
            health =
               "READY";
         }
         else if(m_cache.symbols[i].data_health ==
                 DATA_PARTIAL)
         {
            health =
               "PARTIAL";
         }

         m_logger.Log(
            LOG_LEVEL_DEBUG,
            "MarketDataEngine",
            "MARKET_HEARTBEAT",
            StringFormat(
               "%s | BID=%s | ASK=%s | SPREAD=%d pts | HEALTH=%s | TICK=%s",
               m_cache.symbols[i].symbol,

               DoubleToString(
                  m_cache.symbols[i].bid,
                  m_cache.symbols[i].digits
               ),

               DoubleToString(
                  m_cache.symbols[i].ask,
                  m_cache.symbols[i].digits
               ),

               m_cache.symbols[i].spread_points,

               health,

               TimeToString(
                  m_cache.symbols[i].tick_time,
                  TIME_DATE | TIME_SECONDS
               )
            )
         );
      }
   }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CMarketDataEngine(
      CLogger* logger,
      CSymbolUniverseManager* universe,
      CBarDataManager* bar_mgr,
      CMarketStateCache* cache
   )
      : m_logger(logger),
        m_universe(universe),
        m_bar_manager(bar_mgr),
        m_cache(cache),
        m_last_health_report(0),
        m_health_report_interval_sec(5)
   {
   }

   //+----------------------------------------------------------------+
   //| Initialize market-data engine                                 |
   //+----------------------------------------------------------------+
   bool Initialize()
   {
      int count =
         m_universe.GetSymbolCount();

      if(count <= 0)
      {
         m_logger.Log(
            LOG_LEVEL_ERROR,
            "MarketDataEngine",
            "INIT_FAILED",
            "No symbols available in market universe."
         );

         return false;
      }

      m_cache.Initialize(count);

      int ready_count = 0;

      for(int i = 0;
          i < count;
          i++)
      {
         SSymbolInfo info =
            m_universe.GetSymbol(i);

         m_cache.symbols[i].symbol =
            info.name;

         m_cache.symbols[i].enabled =
            info.available;

         m_cache.symbols[i].data_health =
            DATA_UNAVAILABLE;

         m_cache.symbols[i].bid = 0.0;
         m_cache.symbols[i].ask = 0.0;
         m_cache.symbols[i].last = 0.0;

         m_cache.symbols[i].spread_points = 0;
         m_cache.symbols[i].spread_price = 0.0;

         m_cache.symbols[i].tick_time = 0;
         m_cache.symbols[i].tick_time_msc = 0;
         m_cache.symbols[i].tick_flags = 0;

         m_cache.symbols[i].digits = 0;
         m_cache.symbols[i].point = 0.0;
         m_cache.symbols[i].tick_size = 0.0;
         m_cache.symbols[i].tick_value = 0.0;

         m_cache.symbols[i].volume_min = 0.0;
         m_cache.symbols[i].volume_max = 0.0;
         m_cache.symbols[i].volume_step = 0.0;

         m_cache.symbols[i].stops_level = 0;
         m_cache.symbols[i].freeze_level = 0;

         m_cache.symbols[i].last_update_time = 0;

         if(info.available)
         {
            UpdateStaticProperties(i);

            if(!m_bar_manager.RegisterSymbol(info.name))
            {
               m_logger.Log(
                  LOG_LEVEL_WARNING,
                  "MarketDataEngine",
                  "BAR_REGISTER_WARNING",
                  StringFormat(
                     "Failed to register %s with bar manager.",
                     info.name
                  )
               );
            }

            ready_count++;
         }
      }

      m_logger.Log(
         LOG_LEVEL_INFO,
         "MarketDataEngine",
         "INIT_SUCCESS",
         StringFormat(
            "Market-data engine initialized. %d/%d symbols ready.",
            ready_count,
            count
         )
      );

      return ready_count > 0;
   }

   //+----------------------------------------------------------------+
   //| Load static symbol properties                                 |
   //+----------------------------------------------------------------+
   void UpdateStaticProperties(int index)
   {
      if(index < 0 ||
         index >= ArraySize(m_cache.symbols))
      {
         return;
      }

      string symbol =
         m_cache.symbols[index].symbol;

      if(!m_cache.symbols[index].enabled)
         return;

      m_cache.symbols[index].digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );

      m_cache.symbols[index].point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );

      m_cache.symbols[index].tick_size =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_SIZE
         );

      m_cache.symbols[index].tick_value =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_VALUE
         );

      m_cache.symbols[index].volume_min =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_MIN
         );

      m_cache.symbols[index].volume_max =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_MAX
         );

      m_cache.symbols[index].volume_step =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_STEP
         );

      m_cache.symbols[index].stops_level =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_STOPS_LEVEL
         );

      m_cache.symbols[index].freeze_level =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_FREEZE_LEVEL
         );

      m_logger.Log(
         LOG_LEVEL_DEBUG,
         "MarketDataEngine",
         "SYMBOL_INITIALIZED",
         symbol +
         " market-data properties initialized."
      );
   }

   //+----------------------------------------------------------------+
   //| Process live tick data                                        |
   //+----------------------------------------------------------------+
   void ProcessTicks(CRuntimeState &state)
   {
      int healthy = 0;
      int total = 0;

      for(int i = 0;
          i < ArraySize(m_cache.symbols);
          i++)
      {
         if(!m_cache.symbols[i].enabled)
            continue;

         total++;

         if(ProcessSymbolTick(i))
         {
            healthy++;
         }
      }

      state.healthy_symbols =
         healthy;

      state.total_symbols =
         total;

      if(healthy > 0)
      {
         state.last_successful_update =
            TimeCurrent();
      }

      ReportMarketHealth();
   }

   //+----------------------------------------------------------------+
   //| Process multi-timeframe bars                                  |
   //+----------------------------------------------------------------+
   int ProcessBars()
   {
      int new_bar_count = 0;

      for(int i = 0;
          i < ArraySize(m_cache.symbols);
          i++)
      {
         if(!m_cache.symbols[i].enabled)
            continue;

         if(m_bar_manager.ProcessNewBars(
               m_cache.symbols[i].symbol))
         {
            new_bar_count++;
         }
      }

      return new_bar_count;
   }

   //+----------------------------------------------------------------+
   //| Force immediate health report                                 |
   //+----------------------------------------------------------------+
   void ReportHealthNow()
   {
      m_last_health_report = 0;

      ReportMarketHealth();
   }
};

#endif

//+------------------------------------------------------------------+