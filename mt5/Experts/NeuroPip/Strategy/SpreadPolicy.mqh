//+------------------------------------------------------------------+
//| SpreadPolicy.mqh                                                 |
//| NeuroPip - Phase I Safe Pipeline Repair                          |
//| Canonical Location: Strategy/SpreadPolicy.mqh                    |
//|                                                                  |
//| Centralized Asset-Class Spread Caps & Relative Cost Validation   |
//| Mathematically derived from verified broker metadata:            |
//|   - EURUSDm: 25 pts cap (2.5 pips, typical 8 pts)                |
//|   - USDJPYm: 30 pts cap (3.0 pips, typical 10 pts)               |
//|   - XAUUSDm: 300 pts cap ($0.30 USD, typical 240 pts)            |
//|   - BTCUSDm: 850 pts cap ($8.50 USD, typical 640 pts)            |
//|   - ETHUSDm: 120 pts cap ($1.20 USD, typical 100 pts)            |
//| Dual Filter: Absolute cap + Relative ATR / Reward friction caps  |
//| MONITOR_ONLY - No real money execution                           |
//+------------------------------------------------------------------+
#ifndef ATG_SPREAD_POLICY_MQH
#define ATG_SPREAD_POLICY_MQH

class CSpreadPolicy
{
public:
   //+----------------------------------------------------------------+
   //| Absolute economic spread ceiling in broker points              |
   //+----------------------------------------------------------------+
   static int GetMaxSpreadPoints(const string symbol)
   {
      if(StringFind(symbol, "EURUSD") >= 0) return 25;  // 2.5 pips
      if(StringFind(symbol, "USDJPY") >= 0) return 30;  // 3.0 pips
      if(StringFind(symbol, "XAUUSD") >= 0) return 300; // $0.30 USD
      if(StringFind(symbol, "BTCUSD") >= 0) return 850; // $8.50 USD
      if(StringFind(symbol, "ETHUSD") >= 0) return 120; // $1.20 USD
      return 35; // Default conservative FX ceiling
   }

   //+----------------------------------------------------------------+
   //| Maximum allowable spread cost as a fraction of ATR volatility  |
   //+----------------------------------------------------------------+
   static double GetMaxSpreadAtrRatio(const string symbol)
   {
      if(StringFind(symbol, "XAUUSD") >= 0) return 0.12; // Max 12.0% of ATR on Gold
      if(StringFind(symbol, "BTCUSD") >= 0) return 0.10; // Max 10.0% of ATR on BTC
      return 0.15; // Max 15.0% of ATR on FX and ETH
   }

   //+----------------------------------------------------------------+
   //| Maximum allowable spread cost as a fraction of planned reward  |
   //+----------------------------------------------------------------+
   static double GetMaxSpreadRewardRatio()
   {
      return 0.10; // Spread cannot consume more than 10% of planned reward
   }

   //+----------------------------------------------------------------+
   //| Comprehensive dual spread qualification filter                 |
   //+----------------------------------------------------------------+
   static bool ValidateSpread(const string symbol,
                              int spread_points,
                              double point_size,
                              double atr_price,
                              double reward_price,
                              string &out_rejection_detail)
   {
      // 1. Absolute Spread Cap Check
      int max_pts = GetMaxSpreadPoints(symbol);
      if(spread_points > max_pts)
      {
         out_rejection_detail = StringFormat(
            "Gate (SPREAD_ABSOLUTE): Spread (%d pts) exceeds asset-specific economic cap (%d pts) for %s.",
            spread_points, max_pts, symbol);
         return false;
      }

      // 2. Relative Spread-to-ATR Friction Check
      if(atr_price > 0.0 && point_size > 0.0)
      {
         double spread_price = spread_points * point_size;
         double max_atr_ratio = GetMaxSpreadAtrRatio(symbol);
         double atr_ratio = spread_price / atr_price;
         if(atr_ratio > max_atr_ratio)
         {
            out_rejection_detail = StringFormat(
               "Gate (SPREAD_RELATIVE_ATR): Spread friction (%.2f%% of ATR) exceeds economic threshold (%.2f%%) for %s (Spread: %d pts, ATR: %.5f).",
               atr_ratio * 100.0, max_atr_ratio * 100.0, symbol, spread_points, atr_price);
            return false;
         }
      }

      // 3. Relative Spread-to-Reward Friction Check
      if(reward_price > 0.0 && point_size > 0.0)
      {
         double spread_price = spread_points * point_size;
         double max_rew_ratio = GetMaxSpreadRewardRatio();
         double rew_ratio = spread_price / reward_price;
         if(rew_ratio > max_rew_ratio)
         {
            out_rejection_detail = StringFormat(
               "Gate (SPREAD_RELATIVE_REWARD): Spread cost (%.2f%% of reward) exceeds max allowed (%.2f%%) for %s.",
               rew_ratio * 100.0, max_rew_ratio * 100.0, symbol);
            return false;
         }
      }

      return true;
   }
};

#endif
