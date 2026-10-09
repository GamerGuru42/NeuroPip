//+------------------------------------------------------------------+
//| PositionSizer.mqh                                                |
//| NeuroPip - Phase 2E                                   |
//| Canonical Location: Execution/PositionSizer.mqh                  |
//|                                                                  |
//| Position Sizing Engine                                           |
//| Computes volume from stop distance and risk amount.              |
//| Respects broker min/max/step volume rules.                       |
//| No live orders are sent.                                         |
//+------------------------------------------------------------------+
#ifndef ATG_POSITION_SIZER_MQH
#define ATG_POSITION_SIZER_MQH

#include "../Diagnostics/Logger.mqh"
#include "TradeTypes.mqh"
#include "RiskEngine.mqh"

//+------------------------------------------------------------------+
//| Position size result                                             |
//+------------------------------------------------------------------+
struct SATGPositionSizeResult
{
   double raw_volume;
   double normalized_volume;
   double estimated_loss_at_volume;
   string reason;
};

class CPositionSizer
{
private:
   CLogger* m_logger;

   double NormalizeVolume(double volume, double vol_min, double vol_max, double vol_step)
   {
      if(vol_step <= 0.0) vol_step = 0.01;
      volume = MathFloor(volume / vol_step) * vol_step;
      volume = MathMin(volume, vol_max);
      int digits = (int)MathCeil(-MathLog10(vol_step));
      if(digits < 0) digits = 0;
      return NormalizeDouble(volume, digits);
   }

public:
   CPositionSizer(CLogger* logger)
      : m_logger(logger)
   {
   }

   bool Calculate(const string symbol,
                  ENUM_ATG_TRADE_DIRECTION direction,
                  double entry,
                  double stop_loss,
                  const SATGRiskResult &risk_result,
                  SATGPositionSizeResult &size_result)
   {
      ZeroMemory(size_result);

      double sl_distance = MathAbs(entry - stop_loss);
      if(sl_distance <= 0.0)
      {
         size_result.reason = "Stop loss distance is zero.";
         return false;
      }

      double vol_min  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double vol_max  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double vol_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(vol_min <= 0.0) vol_min = 0.01;
      if(vol_max <= 0.0) vol_max = 100.0;
      if(vol_step <= 0.0) vol_step = 0.01;

      ENUM_ORDER_TYPE order_type = (direction == ATG_DIRECTION_BUY)
         ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      double profit_per_lot = 0.0;
      double loss_per_lot = 0.0;

      if(OrderCalcProfit(order_type, symbol, 1.0, entry, stop_loss, profit_per_lot))
      {
         loss_per_lot = MathAbs(profit_per_lot);
      }

      if(loss_per_lot <= 0.0)
      {
         double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         if(tick_size > 0.0 && tick_value > 0.0)
         {
            loss_per_lot = (sl_distance / tick_size) * tick_value;
         }
      }

      if(loss_per_lot <= 0.0)
      {
         size_result.reason = "Unable to calculate loss per lot for symbol.";
         return false;
      }

      double risk_money = risk_result.risk_money;
      if(risk_money <= 0.0)
      {
         size_result.reason = "Risk money is non-positive.";
         return false;
      }

      // Sizing Feasibility Check: calculate monetary risk at minimum permitted broker volume
      double min_volume_monetary_risk = vol_min * loss_per_lot;
      if(min_volume_monetary_risk > risk_money)
      {
         double required_equity = (risk_result.risk_percent > 0.0)
            ? (min_volume_monetary_risk / (risk_result.risk_percent / 100.0))
            : 0.0;
         size_result.raw_volume = risk_money / loss_per_lot;
         size_result.normalized_volume = 0.0;
         size_result.reason = StringFormat(
            "SIZING_FEASIBILITY_FAILED: Min permitted volume (%.4f) incurs $%.2f risk, exceeding risk budget $%.2f (%.2f%% of $%.2f equity). Min required equity is $%.2f.",
            vol_min, min_volume_monetary_risk, risk_money, risk_result.risk_percent, risk_result.equity, required_equity);
         return false;
      }

      size_result.raw_volume = risk_money / loss_per_lot;
      size_result.normalized_volume = NormalizeVolume(size_result.raw_volume, vol_min, vol_max, vol_step);

      double actual_loss = 0.0;
      if(OrderCalcProfit(order_type, symbol, size_result.normalized_volume, entry, stop_loss, actual_loss))
      {
         size_result.estimated_loss_at_volume = MathAbs(actual_loss);
      }
      else
      {
         size_result.estimated_loss_at_volume = size_result.normalized_volume * loss_per_lot;
      }

      if(size_result.normalized_volume < vol_min)
      {
         size_result.reason = StringFormat("Volume %.4f below minimum allowed %.4f",
            size_result.normalized_volume, vol_min);
         return false;
      }

      size_result.reason = "Position size calculated successfully.";
      return true;
   }

   bool CalculateVolume(SATGTradeIntent &intent, double risk_amount)
   {
      SATGRiskResult risk_res;
      risk_res.risk_money = risk_amount;
      SATGPositionSizeResult size_res;
      double entry = intent.requested_price;
      double sl = intent.stop_loss;
      if(entry <= 0.0)
      {
         entry = (intent.direction == ATG_DIRECTION_BUY) ?
            SymbolInfoDouble(intent.symbol, SYMBOL_ASK) :
            SymbolInfoDouble(intent.symbol, SYMBOL_BID);
      }
      bool ok = Calculate(intent.symbol, intent.direction, entry, sl, risk_res, size_res);
      if(ok)
      {
         intent.volume = size_res.normalized_volume;
         intent.volume_validated = true;
      }
      return ok;
   }
};

#endif
