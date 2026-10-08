//+------------------------------------------------------------------+
//| OrderCheckEngine.mqh                                             |
//| ATG Trading Engine - Phase 2C                                    |
//| Broker Order Preflight / Dry-Run Validation                      |
//|                                                                  |
//| IMPORTANT:                                                       |
//| OrderCheck() DOES NOT SEND A TRADE.                              |
//| This module only constructs a broker request and asks MT5        |
//| whether the request would be accepted.                           |
//+------------------------------------------------------------------+
#ifndef ATG_ORDER_CHECK_ENGINE_MQH
#define ATG_ORDER_CHECK_ENGINE_MQH

#include "../Diagnostics/Logger.mqh"
#include "TradeTypes.mqh"

//+------------------------------------------------------------------+
//| Order-check result                                               |
//+------------------------------------------------------------------+
struct SATGOrderCheckResult
{
   bool   checked;
   bool   accepted;

   uint   retcode;

   double balance;
   double equity;
   double profit;
   double margin;
   double margin_free;
   double margin_level;

   string comment;
};

#define SOrderCheckResult SATGOrderCheckResult

//+------------------------------------------------------------------+
//| Broker Order Check Engine                                        |
//+------------------------------------------------------------------+
class COrderCheckEngine
{
private:

   CLogger* m_logger;

   //+----------------------------------------------------------------+
   //| Convert ATG direction to MT5 order type                        |
   //+----------------------------------------------------------------+
   ENUM_ORDER_TYPE GetOrderType(
      ENUM_ATG_TRADE_DIRECTION direction
   )
   {
      if(direction == ATG_DIRECTION_BUY)
         return ORDER_TYPE_BUY;

      if(direction == ATG_DIRECTION_SELL)
         return ORDER_TYPE_SELL;

      return WRONG_VALUE;
   }

   //+----------------------------------------------------------------+
   //| Select supported filling mode                                  |
   //+----------------------------------------------------------------+
   ENUM_ORDER_TYPE_FILLING GetFillingMode(
      const string symbol
   )
   {
      long filling_flags =
         SymbolInfoInteger(
            symbol,
            SYMBOL_FILLING_MODE
         );

      long trade_execution =
         SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_EXEMODE
         );

      if((filling_flags & SYMBOL_FILLING_FOK) != 0)
         return ORDER_FILLING_FOK;

      if((filling_flags & SYMBOL_FILLING_IOC) != 0)
         return ORDER_FILLING_IOC;

      if(trade_execution != SYMBOL_TRADE_EXECUTION_MARKET)
         return ORDER_FILLING_RETURN;

      return ORDER_FILLING_FOK;
   }

   //+----------------------------------------------------------------+
   //| Build broker request                                           |
   //+----------------------------------------------------------------+
   bool BuildRequest(
      SATGTradeIntent &intent,
      MqlTradeRequest &request
   )
   {
      ZeroMemory(request);

      if(intent.symbol == "")
         return false;

      if(intent.volume <= 0.0)
         return false;

      ENUM_ORDER_TYPE order_type =
         GetOrderType(
            intent.direction
         );

      if(order_type == WRONG_VALUE)
         return false;

      MqlTick tick;

      if(!SymbolInfoTick(
            intent.symbol,
            tick
         ))
      {
         return false;
      }

      int digits =
         (int)SymbolInfoInteger(
            intent.symbol,
            SYMBOL_DIGITS
         );

      double market_price = 0.0;

      if(order_type == ORDER_TYPE_BUY)
         market_price = tick.ask;
      else
         market_price = tick.bid;

      if(market_price <= 0.0)
         return false;

      double request_price =
         intent.requested_price;

      if(request_price <= 0.0)
         request_price = market_price;

      request.action =
         TRADE_ACTION_DEAL;

      request.symbol =
         intent.symbol;

      request.volume =
         intent.volume;

      request.type =
         order_type;

      request.price =
         NormalizeDouble(
            request_price,
            digits
         );

      request.sl = 0.0;
      request.tp = 0.0;

      if(intent.stop_loss > 0.0)
      {
         request.sl =
            NormalizeDouble(
               intent.stop_loss,
               digits
            );
      }

      if(intent.take_profit > 0.0)
      {
         request.tp =
            NormalizeDouble(
               intent.take_profit,
               digits
            );
      }

      request.deviation =
         intent.deviation_points;

      if(request.deviation < 0)
         request.deviation = 0;

      request.type_filling =
         GetFillingMode(
            intent.symbol
         );

      request.type_time =
         ORDER_TIME_GTC;

      request.magic =
         260001;

      request.comment =
         "ATG_ORDER_CHECK";

      return true;
   }

   //+----------------------------------------------------------------+
   //| Convert broker retcode to acceptance                           |
   //+----------------------------------------------------------------+
   bool IsAcceptedRetcode(
      uint retcode
   )
   {
      if(retcode == TRADE_RETCODE_DONE)
         return true;

      if(retcode == TRADE_RETCODE_PLACED)
         return true;

      if(retcode == TRADE_RETCODE_DONE_PARTIAL)
         return true;

      if(retcode == TRADE_RETCODE_CLIENT_DISABLES_AT)
         return true;

      return false;
   }

   //+----------------------------------------------------------------+
   //| Log failure before broker check                                |
   //+----------------------------------------------------------------+
   void LogFailure(
      SATGTradeIntent &intent,
      string message
   )
   {
      if(m_logger == NULL)
         return;

      m_logger.Log(
         LOG_LEVEL_NOTICE,
         "OrderCheckEngine",
         "ORDER_CHECK_FAILED",
         StringFormat(
            "Request=%I64u | Symbol=%s | %s",
            intent.request_id,
            intent.symbol,
            message
         )
      );
   }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   COrderCheckEngine(
      CLogger* logger
   )
      : m_logger(logger)
   {
   }

   //+----------------------------------------------------------------+
   //| Resolve broker symbol with common suffixes                     |
   //+----------------------------------------------------------------+
   string ResolveBrokerSymbol(const string configured_symbol)
   {
      bool is_custom = false;
      if(SymbolExist(configured_symbol, is_custom))
         return configured_symbol;

      string suffixes[] = {"m", "M", "c", "C", ".a", ".b", "pro", "PRO"};
      for(int i = 0; i < ArraySize(suffixes); i++)
      {
         string candidate = configured_symbol + suffixes[i];
         if(SymbolExist(candidate, is_custom))
            return candidate;
      }

      return configured_symbol;
   }

   //+----------------------------------------------------------------+
   //| Get execution mode for broker symbol                           |
   //+----------------------------------------------------------------+
   ENUM_SYMBOL_TRADE_EXECUTION GetExecutionMode(const string symbol)
   {
      return (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
   }

   //+----------------------------------------------------------------+
   //| Build trade request for broker symbol                          |
   //+----------------------------------------------------------------+
   bool BuildTradeRequest(SATGTradeIntent &intent, const string broker_symbol, MqlTradeRequest &request)
   {
      string orig_symbol = intent.symbol;
      intent.symbol = broker_symbol;
      bool res = BuildRequest(intent, request);
      intent.symbol = orig_symbol;
      return res;
   }

   //+----------------------------------------------------------------+
   //| Alias for Check()                                              |
   //+----------------------------------------------------------------+
   bool CheckOrder(SATGTradeIntent &intent, SATGOrderCheckResult &result)
   {
      return Check(intent, result);
   }

   //+----------------------------------------------------------------+
   //| Perform broker-side order preflight                            |
   //+----------------------------------------------------------------+
   bool Check(
      SATGTradeIntent &intent,
      SATGOrderCheckResult &result
   )
   {
      ZeroMemory(result);

      result.checked =
         false;

      result.accepted =
         false;

      result.retcode =
         0;

      MqlTradeRequest request;
      MqlTradeCheckResult check;

      ZeroMemory(request);
      ZeroMemory(check);

      // -------------------------------------------------------------
      // Basic validation
      // -------------------------------------------------------------
      if(intent.symbol == "")
      {
         result.comment =
            "Order check failed: empty symbol.";

         LogFailure(
            intent,
            result.comment
         );

         return false;
      }

      if(intent.volume <= 0.0)
      {
         result.comment =
            "Order check failed: invalid volume.";

         LogFailure(
            intent,
            result.comment
         );

         return false;
      }

      if(intent.direction != ATG_DIRECTION_BUY &&
         intent.direction != ATG_DIRECTION_SELL)
      {
         result.comment =
            "Order check failed: invalid trade direction.";

         LogFailure(
            intent,
            result.comment
         );

         return false;
      }

      // -------------------------------------------------------------
      // Build request
      // -------------------------------------------------------------
      if(!BuildRequest(
            intent,
            request
         ))
      {
         result.comment =
            "Order check failed: unable to build broker request.";

         LogFailure(
            intent,
            result.comment
         );

         return false;
      }

      // -------------------------------------------------------------
      // Broker-side dry-run
      //
      // IMPORTANT:
      // OrderCheck() DOES NOT SEND A TRADE.
      // -------------------------------------------------------------
      ResetLastError();

      bool check_call =
         OrderCheck(
            request,
            check
         );

      int last_error =
         GetLastError();

      result.checked =
         true;

      result.retcode =
         check.retcode;

      result.balance =
         check.balance;

      result.equity =
         check.equity;

      result.profit =
         check.profit;

      result.margin =
         check.margin;

      result.margin_free =
         check.margin_free;

      result.margin_level =
         check.margin_level;

      result.comment =
         check.comment;

      result.accepted =
         (check_call &&
          IsAcceptedRetcode(
             check.retcode
          )) ||
         (check.retcode == TRADE_RETCODE_CLIENT_DISABLES_AT);

      // -------------------------------------------------------------
      // Logging
      // -------------------------------------------------------------
      if(m_logger != NULL)
      {
         if(result.accepted)
         {
            m_logger.Log(
               LOG_LEVEL_INFO,
               "OrderCheckEngine",
               "ORDER_CHECK_PASSED",
               StringFormat(
                  "Request=%I64u | Symbol=%s | Type=%s | Volume=%.8f | Retcode=%u | Comment=%s",
                  intent.request_id,
                  intent.symbol,
                  EnumToString(request.type),
                  request.volume,
                  check.retcode,
                  check.comment
               )
            );
         }
         else
         {
            m_logger.Log(
               LOG_LEVEL_NOTICE,
               "OrderCheckEngine",
               "ORDER_CHECK_REJECTED",
               StringFormat(
                  "Request=%I64u | Symbol=%s | Type=%s | Volume=%.8f | Retcode=%u | Error=%d | Comment=%s",
                  intent.request_id,
                  intent.symbol,
                  EnumToString(request.type),
                  request.volume,
                  check.retcode,
                  last_error,
                  check.comment
               )
            );
         }
      }

      return result.accepted;
   }
};

#endif

//+------------------------------------------------------------------+