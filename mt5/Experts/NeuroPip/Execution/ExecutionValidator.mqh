//+------------------------------------------------------------------+
//| ExecutionValidator.mqh                                          |
//| NeuroPip - Phase 2B                                   |
//| Pre-Execution Validation                                        |
//|                                                                  |
//| This module performs validation only.                           |
//| It does NOT send, modify, or close trades.                      |
//+------------------------------------------------------------------+
#ifndef ATG_EXECUTION_VALIDATOR_MQH
#define ATG_EXECUTION_VALIDATOR_MQH

#include "../Diagnostics/Logger.mqh"
#include "TradeTypes.mqh"

class CExecutionValidator
{
private:

   CLogger* m_logger;

public:

   CExecutionValidator(CLogger* logger)
      : m_logger(logger)
   {
   }

   //+--------------------------------------------------------------+
   //| Validate complete trade intent                               |
   //+--------------------------------------------------------------+
   bool Validate(
      SATGTradeIntent &intent
   )
   {
      intent.state =
         ATG_EXECUTION_VALIDATING;

      intent.rejection_reason =
         ATG_REJECT_NONE;

      // -----------------------------------------------------------
      // Symbol
      // -----------------------------------------------------------
      if(!ValidateSymbol(intent))
         return false;

      // -----------------------------------------------------------
      // Direction
      // -----------------------------------------------------------
      if(!ValidateDirection(intent))
         return false;

      // -----------------------------------------------------------
      // Volume
      // -----------------------------------------------------------
      if(!ValidateVolume(intent))
         return false;

      // -----------------------------------------------------------
      // Price
      // -----------------------------------------------------------
      if(!ValidatePrice(intent))
         return false;

      // -----------------------------------------------------------
      // Spread
      // -----------------------------------------------------------
      if(!ValidateSpread(intent))
         return false;

      // -----------------------------------------------------------
      // Stop loss / take profit
      // -----------------------------------------------------------
      if(!ValidateStops(intent))
         return false;

      intent.state =
         ATG_EXECUTION_CHECKED;

      return true;
   }

private:

   //+--------------------------------------------------------------+
   //| Symbol validation                                             |
   //+--------------------------------------------------------------+
   bool ValidateSymbol(
      SATGTradeIntent &intent
   )
   {
      if(intent.symbol == "")
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_SYMBOL,
            "Symbol is empty."
         );

         return false;
      }

      if(!SymbolSelect(intent.symbol, true))
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_SYMBOL,
            StringFormat(
               "SymbolSelect failed for %s.",
               intent.symbol
            )
         );

         return false;
      }

      long trade_mode =
         SymbolInfoInteger(
            intent.symbol,
            SYMBOL_TRADE_MODE
         );

      if(trade_mode ==
         SYMBOL_TRADE_MODE_DISABLED)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_SYMBOL,
            StringFormat(
               "Trading is disabled for %s.",
               intent.symbol
            )
         );

         return false;
      }

      intent.symbol_validated =
         true;

      return true;
   }

   //+--------------------------------------------------------------+
   //| Direction validation                                          |
   //+--------------------------------------------------------------+
   bool ValidateDirection(
      SATGTradeIntent &intent
   )
   {
      if(intent.direction != ATG_DIRECTION_BUY &&
         intent.direction != ATG_DIRECTION_SELL)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_DIRECTION,
            "Direction must be BUY or SELL."
         );

         return false;
      }

      return true;
   }

   //+--------------------------------------------------------------+
   //| Volume validation                                             |
   //+--------------------------------------------------------------+
   bool ValidateVolume(
      SATGTradeIntent &intent
   )
   {
      double volume_min =
         SymbolInfoDouble(
            intent.symbol,
            SYMBOL_VOLUME_MIN
         );

      double volume_max =
         SymbolInfoDouble(
            intent.symbol,
            SYMBOL_VOLUME_MAX
         );

      double volume_step =
         SymbolInfoDouble(
            intent.symbol,
            SYMBOL_VOLUME_STEP
         );

      if(volume_min <= 0.0 ||
         volume_max <= 0.0 ||
         volume_step <= 0.0)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_VOLUME,
            "Broker returned invalid volume specifications."
         );

         return false;
      }

      if(intent.volume < volume_min)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_VOLUME,
            StringFormat(
               "Volume %.8f is below minimum %.8f.",
               intent.volume,
               volume_min
            )
         );

         return false;
      }

      if(intent.volume > volume_max)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_VOLUME,
            StringFormat(
               "Volume %.8f exceeds maximum %.8f.",
               intent.volume,
               volume_max
            )
         );

         return false;
      }

      double steps =
         intent.volume / volume_step;

      double rounded_steps =
         MathRound(steps);

      if(MathAbs(
            steps - rounded_steps
         ) > 0.0000001)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_VOLUME,
            StringFormat(
               "Volume %.8f does not match broker step %.8f.",
               intent.volume,
               volume_step
            )
         );

         return false;
      }

      intent.volume_validated =
         true;

      return true;
   }

   //+--------------------------------------------------------------+
   //| Price validation                                              |
   //+--------------------------------------------------------------+
   bool ValidatePrice(
      SATGTradeIntent &intent
   )
   {
      MqlTick tick;

      if(!SymbolInfoTick(
            intent.symbol,
            tick))
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_PRICE,
            StringFormat(
               "Unable to obtain tick for %s.",
               intent.symbol
            )
         );

         return false;
      }

      double point =
         SymbolInfoDouble(
            intent.symbol,
            SYMBOL_POINT
         );

      int digits =
         (int)SymbolInfoInteger(
            intent.symbol,
            SYMBOL_DIGITS
         );

      if(point <= 0.0 ||
         digits < 0)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_PRICE,
            "Invalid symbol price specification."
         );

         return false;
      }

      double market_price = 0.0;

      if(intent.direction ==
         ATG_DIRECTION_BUY)
      {
         market_price =
            tick.ask;
      }
      else
      {
         market_price =
            tick.bid;
      }

      if(market_price <= 0.0)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_PRICE,
            "Market price is invalid."
         );

         return false;
      }

      // If no requested price was supplied,
      // use current market price.
      if(intent.requested_price <= 0.0)
      {
         intent.requested_price =
            NormalizeDouble(
               market_price,
               digits
            );
      }

      if(intent.requested_price <= 0.0)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_PRICE,
            "Requested price is invalid."
         );

         return false;
      }

      intent.price_validated =
         true;

      return true;
   }

   //+--------------------------------------------------------------+
   //| Spread validation                                             |
   //+--------------------------------------------------------------+
   bool ValidateSpread(
      SATGTradeIntent &intent
   )
   {
      MqlTick tick;

      if(!SymbolInfoTick(
            intent.symbol,
            tick))
      {
         Reject(
            intent,
            ATG_REJECT_SPREAD,
            "Unable to obtain tick for spread validation."
         );

         return false;
      }

      double point =
         SymbolInfoDouble(
            intent.symbol,
            SYMBOL_POINT
         );

      if(point <= 0.0)
      {
         Reject(
            intent,
            ATG_REJECT_SPREAD,
            "Invalid symbol point value."
         );

         return false;
      }

      double spread_price =
         tick.ask - tick.bid;

      if(spread_price < 0.0)
      {
         Reject(
            intent,
            ATG_REJECT_SPREAD,
            "Broker returned an invalid spread."
         );

         return false;
      }

      int spread_points =
         (int)MathRound(
            spread_price / point
         );

      if(intent.max_spread_points > 0 &&
         spread_points >
         intent.max_spread_points)
      {
         Reject(
            intent,
            ATG_REJECT_SPREAD,
            StringFormat(
               "Spread %d points exceeds maximum %d points.",
               spread_points,
               intent.max_spread_points
            )
         );

         return false;
      }

      intent.spread_validated =
         true;

      return true;
   }

   //+--------------------------------------------------------------+
   //| Stop-loss / take-profit validation                            |
   //+--------------------------------------------------------------+
   bool ValidateStops(
      SATGTradeIntent &intent
   )
   {
      double point =
         SymbolInfoDouble(
            intent.symbol,
            SYMBOL_POINT
         );

      int digits =
         (int)SymbolInfoInteger(
            intent.symbol,
            SYMBOL_DIGITS
         );

      long stops_level =
         SymbolInfoInteger(
            intent.symbol,
            SYMBOL_TRADE_STOPS_LEVEL
         );

      if(point <= 0.0)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_STOPS,
            "Invalid point size."
         );

         return false;
      }

      double minimum_distance =
         (double)stops_level * point;

      // -----------------------------------------------------------
      // BUY
      // -----------------------------------------------------------
      if(intent.direction ==
         ATG_DIRECTION_BUY)
      {
         if(intent.stop_loss > 0.0)
         {
            double distance =
               intent.requested_price -
               intent.stop_loss;

            if(distance < minimum_distance)
            {
               Reject(
                  intent,
                  ATG_REJECT_INVALID_STOPS,
                  StringFormat(
                     "BUY stop-loss distance is too small. Required %.8f.",
                     minimum_distance
                  )
               );

               return false;
            }

            if(intent.stop_loss >=
               intent.requested_price)
            {
               Reject(
                  intent,
                  ATG_REJECT_INVALID_STOPS,
                  "BUY stop-loss must be below entry price."
               );

               return false;
            }

            intent.stop_loss =
               NormalizeDouble(
                  intent.stop_loss,
                  digits
               );
         }

         if(intent.take_profit > 0.0)
         {
            double distance =
               intent.take_profit -
               intent.requested_price;

            if(distance < minimum_distance)
            {
               Reject(
                  intent,
                  ATG_REJECT_INVALID_STOPS,
                  StringFormat(
                     "BUY take-profit distance is too small. Required %.8f.",
                     minimum_distance
                  )
               );

               return false;
            }

            if(intent.take_profit <=
               intent.requested_price)
            {
               Reject(
                  intent,
                  ATG_REJECT_INVALID_STOPS,
                  "BUY take-profit must be above entry price."
               );

               return false;
            }

            intent.take_profit =
               NormalizeDouble(
                  intent.take_profit,
                  digits
               );
         }
      }

      // -----------------------------------------------------------
      // SELL
      // -----------------------------------------------------------
      if(intent.direction ==
         ATG_DIRECTION_SELL)
      {
         if(intent.stop_loss > 0.0)
         {
            double distance =
               intent.stop_loss -
               intent.requested_price;

            if(distance < minimum_distance)
            {
               Reject(
                  intent,
                  ATG_REJECT_INVALID_STOPS,
                  StringFormat(
                     "SELL stop-loss distance is too small. Required %.8f.",
                     minimum_distance
                  )
               );

               return false;
            }

            if(intent.stop_loss <=
               intent.requested_price)
            {
               Reject(
                  intent,
                  ATG_REJECT_INVALID_STOPS,
                  "SELL stop-loss must be above entry price."
               );

               return false;
            }

            intent.stop_loss =
               NormalizeDouble(
                  intent.stop_loss,
                  digits
               );
         }

         if(intent.take_profit > 0.0)
         {
            double distance =
               intent.requested_price -
               intent.take_profit;

            if(distance < minimum_distance)
            {
               Reject(
                  intent,
                  ATG_REJECT_INVALID_STOPS,
                  StringFormat(
                     "SELL take-profit distance is too small. Required %.8f.",
                     minimum_distance
                  )
               );

               return false;
            }

            if(intent.take_profit >=
               intent.requested_price)
            {
               Reject(
                  intent,
                  ATG_REJECT_INVALID_STOPS,
                  "SELL take-profit must be below entry price."
               );

               return false;
            }

            intent.take_profit =
               NormalizeDouble(
                  intent.take_profit,
                  digits
               );
         }
      }

      intent.stops_validated =
         true;

      return true;
   }

   //+--------------------------------------------------------------+
   //| Reject request                                                |
   //+--------------------------------------------------------------+
   void Reject(
      SATGTradeIntent &intent,
      ENUM_ATG_REJECTION_REASON reason,
      string message
   )
   {
      intent.state =
         ATG_EXECUTION_REJECTED;

      intent.rejection_reason =
         reason;

      if(m_logger != NULL)
      {
         m_logger.Log(
            LOG_LEVEL_NOTICE,
            "ExecutionValidator",
            "VALIDATION_REJECTED",
            StringFormat(
               "Request=%I64u | Symbol=%s | %s",
               intent.request_id,
               intent.symbol,
               message
            )
         );
      }
   }
};

#endif

//+------------------------------------------------------------------+