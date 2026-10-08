//+------------------------------------------------------------------+
//| MarketFeatureEngine.mqh                                          |
//| ATG Trading Engine - Phase 3                                     |
//| Multi-Timeframe Observable Market Features Calculator            |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_MARKET_FEATURE_ENGINE_MQH
#define ATG_MARKET_FEATURE_ENGINE_MQH

#include "MarketFeatureTypes.mqh"
#include "../MarketData/MarketStateCache.mqh"
#include "../MarketData/SymbolUniverseManager.mqh"
#include "../MarketData/BarDataManager.mqh"
#include "../Diagnostics/Logger.mqh"

class CMarketFeatureEngine
{
private:
   CLogger*                m_logger;
   CSymbolUniverseManager* m_universe;
   CBarDataManager*        m_bar_manager;
   CMarketStateCache*      m_cache;

   // Minimum historical closed bars required for reliable feature extraction
   int                     m_min_bars;

   //+----------------------------------------------------------------+
   //| Convert timeframe to string label                              |
   //+----------------------------------------------------------------+
   string TimeframeToLabel(ENUM_TIMEFRAMES tf)
   {
      switch(tf)
      {
         case PERIOD_M1:  return "M1";
         case PERIOD_M5:  return "M5";
         case PERIOD_M15: return "M15";
         case PERIOD_H1:  return "H1";
         case PERIOD_H4:  return "H4";
         case PERIOD_D1:  return "D1";
      }
      return "TF";
   }

   //+----------------------------------------------------------------+
   //| Calculate Exponential Moving Average over MqlRates series      |
   //+----------------------------------------------------------------+
   double CalculateEMA(const MqlRates &rates[], int total, int period, int shift = 0)
   {
      if(total < period + shift || period <= 0)
         return 0.0;

      double multiplier = 2.0 / (double)(period + 1);

      // Initialize with SMA of the oldest window
      int start_idx = total - 1;
      double sma_sum = 0.0;
      for(int i = 0; i < period && (start_idx - i) >= 0; i++)
      {
         sma_sum += rates[start_idx - i].close;
      }
      double current_ema = sma_sum / (double)period;

      // Walk forward to shift index (rates[0] is newest closed bar)
      for(int i = start_idx - period; i >= shift; i--)
      {
         current_ema = ((rates[i].close - current_ema) * multiplier) + current_ema;
      }

      return current_ema;
   }

   //+----------------------------------------------------------------+
   //| Calculate Simple Moving Average over MqlRates series           |
   //+----------------------------------------------------------------+
   double CalculateSMA(const MqlRates &rates[], int total, int period, int shift = 0)
   {
      if(total < period + shift || period <= 0)
         return 0.0;

      double sum = 0.0;
      for(int i = 0; i < period; i++)
      {
         sum += rates[shift + i].close;
      }
      return (sum / (double)period);
   }

   //+----------------------------------------------------------------+
   //| Calculate Wilder's Average True Range (ATR)                    |
   //+----------------------------------------------------------------+
   double CalculateATR(const MqlRates &rates[], int total, int period, int shift = 0)
   {
      if(total < period + shift + 1 || period <= 0)
         return 0.0;

      double tr_sum = 0.0;
      for(int i = 0; i < period; i++)
      {
         int idx = shift + i;
         double high = rates[idx].high;
         double low  = rates[idx].low;
         double prev_close = rates[idx + 1].close;

         double tr1 = high - low;
         double tr2 = MathAbs(high - prev_close);
         double tr3 = MathAbs(low - prev_close);

         double tr = MathMax(tr1, MathMax(tr2, tr3));
         tr_sum += tr;
      }

      return (tr_sum / (double)period);
   }

   //+----------------------------------------------------------------+
   //| Calculate Relative Strength Index (RSI)                        |
   //+----------------------------------------------------------------+
   double CalculateRSI(const MqlRates &rates[], int total, int period, int shift = 0)
   {
      if(total < period + shift + 1 || period <= 0)
         return 50.0;

      double gain_sum = 0.0;
      double loss_sum = 0.0;

      for(int i = 0; i < period; i++)
      {
         int idx = shift + i;
         double change = rates[idx].close - rates[idx + 1].close;
         if(change > 0.0)
            gain_sum += change;
         else
            loss_sum += MathAbs(change);
      }

      double avg_gain = gain_sum / (double)period;
      double avg_loss = loss_sum / (double)period;

      if(avg_loss == 0.0)
         return 100.0;
      if(avg_gain == 0.0)
         return 0.0;

      double rs = avg_gain / avg_loss;
      return 100.0 - (100.0 / (1.0 + rs));
   }

   //+----------------------------------------------------------------+
   //| Populate price structure from latest closed bar                |
   //+----------------------------------------------------------------+
   void PopulatePriceStructure(const MqlRates &rates[], int copied, double point, SPriceStructure &ps)
   {
      ps.open              = rates[0].open;
      ps.high              = rates[0].high;
      ps.low               = rates[0].low;
      ps.close             = rates[0].close;
      ps.prev_close        = (copied > 1) ? rates[1].close : rates[0].open;
      ps.current_price     = rates[0].close;
      ps.range_points      = (ps.high - ps.low) / point;
      ps.body_points       = MathAbs(ps.close - ps.open) / point;
      ps.upper_wick_points = (ps.high - MathMax(ps.open, ps.close)) / point;
      ps.lower_wick_points = (MathMin(ps.open, ps.close) - ps.low) / point;

      if(ps.close > ps.open)
         ps.candle_type = CANDLE_BULLISH;
      else if(ps.close < ps.open)
         ps.candle_type = CANDLE_BEARISH;
      else
         ps.candle_type = CANDLE_DOJI;

      ps.is_valid = (ps.high >= ps.low && ps.high > 0.0 && ps.range_points >= 0.0);
   }

   //+----------------------------------------------------------------+
   //| Populate volatility features                                   |
   //+----------------------------------------------------------------+
   void PopulateVolatility(const MqlRates &rates[], int copied, double point, double close_price, SVolatilityFeatures &vf)
   {
      double atr14 = CalculateATR(rates, copied, 14, 0);
      if(atr14 > 0.0)
      {
         vf.atr              = atr14;
         vf.atr_points       = atr14 / point;
         vf.atr_relative_pct = (close_price > 0.0) ? ((atr14 / close_price) * 100.0) : 0.0;

         // Ratio to 40-period baseline ATR if depth allows
         double atr40 = (copied >= 42) ? CalculateATR(rates, copied, 40, 0) : atr14;
         if(atr40 > 0.0)
            vf.atr_ratio_to_avg = atr14 / atr40;
         else
            vf.atr_ratio_to_avg = 1.0;

         if(vf.atr_ratio_to_avg > 1.35)
            vf.vol_state = VOL_HIGH;
         else if(vf.atr_ratio_to_avg < 0.70)
            vf.vol_state = VOL_LOW;
         else
            vf.vol_state = VOL_NORMAL;

         vf.is_valid = true;
      }
      else
      {
         vf.is_valid = false;
      }
   }

   //+----------------------------------------------------------------+
   //| Populate trend features                                        |
   //+----------------------------------------------------------------+
   void PopulateTrend(const MqlRates &rates[], int copied, double point, double close_price, STrendFeatures &tf_feat)
   {
      double ema20 = CalculateEMA(rates, copied, 20, 0);
      double ema50 = (copied >= 50) ? CalculateEMA(rates, copied, 50, 0) : CalculateEMA(rates, copied, copied - 1, 0);
      double ema20_prev = CalculateEMA(rates, copied, 20, 2);

      if(ema20 > 0.0 && ema50 > 0.0)
      {
         tf_feat.fast_ma          = ema20;
         tf_feat.slow_ma          = ema50;
         tf_feat.ma_bullish_align = (ema20 > ema50);
         tf_feat.ma_slope_points  = (ema20 - ema20_prev) / (2.0 * point);
         tf_feat.price_vs_fast_ma = (close_price - ema20) / point;
         tf_feat.price_vs_slow_ma = (close_price - ema50) / point;

         // Baseline MA (e.g. SMA of available depth, up to 75)
         int base_period = MathMin(75, copied);
         tf_feat.baseline_ma       = CalculateSMA(rates, copied, base_period, 0);
         tf_feat.price_vs_baseline = (close_price - tf_feat.baseline_ma) / point;

         // Directional consistency over recent 10 bars
         int bullish_bars = 0;
         int check_bars = MathMin(10, copied);
         for(int i = 0; i < check_bars; i++)
         {
            if(rates[i].close > rates[i].open)
               bullish_bars++;
         }
         tf_feat.directional_consistency = (double)bullish_bars / (double)check_bars;

         // Trend classification
         if(tf_feat.ma_bullish_align && tf_feat.price_vs_fast_ma > -10.0 && tf_feat.ma_slope_points > -0.5)
            tf_feat.trend_direction = TREND_BULLISH;
         else if(!tf_feat.ma_bullish_align && tf_feat.price_vs_fast_ma < 10.0 && tf_feat.ma_slope_points < 0.5)
            tf_feat.trend_direction = TREND_BEARISH;
         else
            tf_feat.trend_direction = TREND_FLAT;

         tf_feat.is_valid = true;
      }
      else
      {
         tf_feat.is_valid = false;
      }
   }

   //+----------------------------------------------------------------+
   //| Populate momentum features                                     |
   //+----------------------------------------------------------------+
   void PopulateMomentum(const MqlRates &rates[], int copied, double point, SMomentumFeatures &mf)
   {
      double rsi14 = CalculateRSI(rates, copied, 14, 0);
      mf.rsi              = rsi14;
      mf.is_overbought    = (rsi14 >= 70.0);
      mf.is_oversold      = (rsi14 <= 30.0);

      if(copied >= 11)
      {
         mf.momentum_points  = (rates[0].close - rates[10].close) / point;
         mf.price_change_pct = (rates[10].close > 0.0) ?
            (((rates[0].close - rates[10].close) / rates[10].close) * 100.0) : 0.0;
      }

      if(rsi14 > 53.0 && mf.momentum_points > 0.0)
         mf.momentum_bias = TREND_BULLISH;
      else if(rsi14 < 47.0 && mf.momentum_points < 0.0)
         mf.momentum_bias = TREND_BEARISH;
      else
         mf.momentum_bias = TREND_FLAT;

      mf.is_valid = (rsi14 >= 0.0 && rsi14 <= 100.0);
   }

   //+----------------------------------------------------------------+
   //| Populate market structure features                             |
   //+----------------------------------------------------------------+
   void PopulateStructure(const MqlRates &rates[], int copied, double point, SMarketStructureFeatures &str_feat)
   {
      int swing_window = MathMin(20, copied);
      double high_max = rates[0].high;
      double low_min  = rates[0].low;

      for(int i = 1; i < swing_window; i++)
      {
         if(rates[i].high > high_max) high_max = rates[i].high;
         if(rates[i].low < low_min)   low_min  = rates[i].low;
      }

      str_feat.recent_swing_high  = high_max;
      str_feat.recent_swing_low   = low_min;
      str_feat.range_width_points = (high_max - low_min) / point;

      // Higher High / Lower Low check comparing halves of the window
      int half = swing_window / 2;
      double recent_high = rates[0].high;
      double older_high  = rates[half].high;
      double recent_low  = rates[0].low;
      double older_low   = rates[half].low;

      for(int i = 0; i < half; i++)
      {
         if(rates[i].high > recent_high) recent_high = rates[i].high;
         if(rates[i].low < recent_low)   recent_low  = rates[i].low;
      }
      for(int i = half; i < swing_window; i++)
      {
         if(rates[i].high > older_high) older_high = rates[i].high;
         if(rates[i].low < older_low)   older_low  = rates[i].low;
      }

      str_feat.higher_high = (recent_high > older_high);
      str_feat.higher_low  = (recent_low > older_low);
      str_feat.lower_high  = (recent_high < older_high);
      str_feat.lower_low   = (recent_low < older_low);

      if(str_feat.higher_high && str_feat.higher_low)
         str_feat.structure_state = STRUCT_HIGHER_HIGHS_LOWS;
      else if(str_feat.lower_high && str_feat.lower_low)
         str_feat.structure_state = STRUCT_LOWER_HIGHS_LOWS;
      else
         str_feat.structure_state = STRUCT_RANGING;

      str_feat.is_valid = (str_feat.range_width_points > 0.0);
   }

   //+----------------------------------------------------------------+
   //| Populate spread / health features                              |
   //+----------------------------------------------------------------+
   void PopulateSpread(const string symbol, double point, SSpreadFeatures &sf)
   {
      MqlTick live_tick;
      if(SymbolInfoTick(symbol, live_tick) && live_tick.ask > 0.0 && live_tick.bid > 0.0)
      {
         sf.bid               = live_tick.bid;
         sf.ask               = live_tick.ask;
         sf.spread_price      = live_tick.ask - live_tick.bid;
         sf.spread_points     = (int)MathRound(sf.spread_price / point);
         sf.spread_acceptable = (sf.spread_points > 0 && sf.spread_points < 3000);
         sf.data_ready        = true;
      }
   }

public:
   CMarketFeatureEngine(CLogger* logger = NULL,
                        CSymbolUniverseManager* universe = NULL,
                        CBarDataManager* bar_manager = NULL,
                        CMarketStateCache* cache = NULL)
      : m_logger(logger),
        m_universe(universe),
        m_bar_manager(bar_manager),
        m_cache(cache),
        m_min_bars(30)
   {
   }

   //+----------------------------------------------------------------+
   //| Extract features for a single symbol and timeframe             |
   //+----------------------------------------------------------------+
   bool ExtractTimeframeFeatures(const string symbol,
                                 ENUM_TIMEFRAMES tf,
                                 STimeframeFeatures &out_features)
   {
      out_features.Reset();
      out_features.timeframe       = tf;
      out_features.timeframe_label = TimeframeToLabel(tf);

      if(symbol == "")
         return false;

      // 1. Point size and digits
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(point <= 0.0)
         return false;

      // 2. Fetch history closed bars
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      ResetLastError();

      // Read up to 80 closed bars (starting at bar 1: closed bars only)
      int requested_bars = 80;
      int copied = CopyRates(symbol, tf, 1, requested_bars, rates);
      if(copied < m_min_bars)
      {
         out_features.data_ready = false;
         return false;
      }

      out_features.bar_time = rates[0].time;

      // 3. Populate feature components
      PopulatePriceStructure(rates, copied, point, out_features.price);
      PopulateVolatility(rates, copied, point, out_features.price.close, out_features.volatility);
      PopulateTrend(rates, copied, point, out_features.price.close, out_features.trend);
      PopulateMomentum(rates, copied, point, out_features.momentum);
      PopulateStructure(rates, copied, point, out_features.structure);
      PopulateSpread(symbol, point, out_features.spread);

      out_features.data_ready = (out_features.price.is_valid &&
                                 out_features.volatility.is_valid &&
                                 out_features.trend.is_valid &&
                                 out_features.momentum.is_valid);
      return out_features.data_ready;
   }

   //+----------------------------------------------------------------+
   //| Extract multi-timeframe composite features for a symbol        |
   //+----------------------------------------------------------------+
   bool ExtractMultiTimeframeFeatures(const string symbol,
                                      SMultiTimeframeFeatures &out_mtf)
   {
      out_mtf.Reset();
      out_mtf.symbol          = symbol;
      out_mtf.evaluation_time = TimeCurrent();

      if(symbol == "")
         return false;

      // Extract each configured timeframe
      bool ok_m1  = ExtractTimeframeFeatures(symbol, PERIOD_M1,  out_mtf.tf_m1);
      bool ok_m5  = ExtractTimeframeFeatures(symbol, PERIOD_M5,  out_mtf.tf_m5);
      bool ok_m15 = ExtractTimeframeFeatures(symbol, PERIOD_M15, out_mtf.tf_m15);
      bool ok_h1  = ExtractTimeframeFeatures(symbol, PERIOD_H1,  out_mtf.tf_h1);
      bool ok_h4  = ExtractTimeframeFeatures(symbol, PERIOD_H4,  out_mtf.tf_h4);
      bool ok_d1  = ExtractTimeframeFeatures(symbol, PERIOD_D1,  out_mtf.tf_d1);

      // We consider the multi-timeframe view ready if core timeframes (M15, H1, H4) are ready
      out_mtf.overall_data_ready = (ok_m15 && ok_h1 && ok_h4);

      if(!out_mtf.overall_data_ready && m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_DEBUG, "FeatureEngine", "DATA_PARTIAL",
            StringFormat("%s multi-timeframe features partial: M1=%d M5=%d M15=%d H1=%d H4=%d D1=%d",
               symbol, ok_m1, ok_m5, ok_m15, ok_h1, ok_h4, ok_d1));
      }

      return out_mtf.overall_data_ready;
   }
};

#endif
