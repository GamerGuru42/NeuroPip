//+------------------------------------------------------------------+
//| MarketFeatureTypes.mqh                                           |
//| NeuroPip - Phase 3                                     |
//| Market Features Data Types and Structures                        |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_MARKET_FEATURE_TYPES_MQH
#define ATG_MARKET_FEATURE_TYPES_MQH

//+------------------------------------------------------------------+
//| Candle direction/shape classification                            |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_TYPE
{
   CANDLE_DOJI = 0,
   CANDLE_BULLISH,
   CANDLE_BEARISH
};

//+------------------------------------------------------------------+
//| Volatility state classification                                  |
//+------------------------------------------------------------------+
enum ENUM_VOLATILITY_STATE
{
   VOL_UNKNOWN = 0,
   VOL_LOW,
   VOL_NORMAL,
   VOL_HIGH,
   VOL_EXPANDING,
   VOL_COMPRESSING
};

//+------------------------------------------------------------------+
//| Trend direction classification                                   |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
   TREND_UNKNOWN = 0,
   TREND_FLAT,
   TREND_BULLISH,
   TREND_BEARISH
};

//+------------------------------------------------------------------+
//| Market structure swing classification                            |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_STATE
{
   STRUCT_UNKNOWN = 0,
   STRUCT_RANGING,
   STRUCT_HIGHER_HIGHS_LOWS,
   STRUCT_LOWER_HIGHS_LOWS,
   STRUCT_BREAKOUT_BULLISH,
   STRUCT_BREAKOUT_BEARISH
};

//+------------------------------------------------------------------+
//| Price structure features for a single candle / bar               |
//+------------------------------------------------------------------+
struct SPriceStructure
{
   double            current_price;
   double            prev_close;
   double            open;
   double            high;
   double            low;
   double            close;
   double            body_points;
   double            upper_wick_points;
   double            lower_wick_points;
   double            range_points;
   ENUM_CANDLE_TYPE  candle_type;
   bool              is_valid;

   void Reset()
   {
      current_price     = 0.0;
      prev_close        = 0.0;
      open              = 0.0;
      high              = 0.0;
      low               = 0.0;
      close             = 0.0;
      body_points       = 0.0;
      upper_wick_points = 0.0;
      lower_wick_points = 0.0;
      range_points      = 0.0;
      candle_type       = CANDLE_DOJI;
      is_valid          = false;
   }
};

//+------------------------------------------------------------------+
//| Volatility features                                              |
//+------------------------------------------------------------------+
struct SVolatilityFeatures
{
   double                atr;
   double                atr_points;
   double                atr_relative_pct;  // ATR as % of current price
   double                atr_ratio_to_avg;  // Current ATR vs 50-period ATR
   ENUM_VOLATILITY_STATE vol_state;
   bool                  is_valid;

   void Reset()
   {
      atr              = 0.0;
      atr_points       = 0.0;
      atr_relative_pct = 0.0;
      atr_ratio_to_avg = 1.0;
      vol_state        = VOL_UNKNOWN;
      is_valid         = false;
   }
};

//+------------------------------------------------------------------+
//| Trend features                                                   |
//+------------------------------------------------------------------+
struct STrendFeatures
{
   double                fast_ma;            // e.g. EMA 20
   double                slow_ma;            // e.g. EMA 50
   double                baseline_ma;        // e.g. SMA 200
   bool                  ma_bullish_align;   // fast > slow
   double                ma_slope_points;    // slope of fast MA over last 3 bars
   double                price_vs_fast_ma;   // close - fast_ma in points
   double                price_vs_slow_ma;   // close - slow_ma in points
   double                price_vs_baseline;  // close - baseline in points
   double                directional_consistency; // % of recent bars in trend direction (0.0 - 1.0)
   ENUM_TREND_DIRECTION  trend_direction;
   bool                  is_valid;

   void Reset()
   {
      fast_ma                  = 0.0;
      slow_ma                  = 0.0;
      baseline_ma              = 0.0;
      ma_bullish_align         = false;
      ma_slope_points          = 0.0;
      price_vs_fast_ma         = 0.0;
      price_vs_slow_ma         = 0.0;
      price_vs_baseline        = 0.0;
      directional_consistency  = 0.5;
      trend_direction          = TREND_UNKNOWN;
      is_valid                 = false;
   }
};

//+------------------------------------------------------------------+
//| Momentum features                                                |
//+------------------------------------------------------------------+
struct SMomentumFeatures
{
   double                rsi;
   double                momentum_points;    // close[0] - close[10]
   double                price_change_pct;   // % change over last N bars
   bool                  is_overbought;      // RSI > 70
   bool                  is_oversold;        // RSI < 30
   ENUM_TREND_DIRECTION  momentum_bias;
   bool                  is_valid;

   void Reset()
   {
      rsi              = 50.0;
      momentum_points  = 0.0;
      price_change_pct = 0.0;
      is_overbought    = false;
      is_oversold      = false;
      momentum_bias    = TREND_UNKNOWN;
      is_valid         = false;
   }
};

//+------------------------------------------------------------------+
//| Market structure features                                        |
//+------------------------------------------------------------------+
struct SMarketStructureFeatures
{
   double                recent_swing_high;
   double                recent_swing_low;
   double                range_width_points;
   bool                  higher_high;
   bool                  higher_low;
   bool                  lower_high;
   bool                  lower_low;
   ENUM_STRUCTURE_STATE  structure_state;
   bool                  is_valid;

   void Reset()
   {
      recent_swing_high  = 0.0;
      recent_swing_low   = 0.0;
      range_width_points = 0.0;
      higher_high        = false;
      higher_low         = false;
      lower_high         = false;
      lower_low          = false;
      structure_state    = STRUCT_UNKNOWN;
      is_valid           = false;
   }
};

//+------------------------------------------------------------------+
//| Spread and market health snapshot                                |
//+------------------------------------------------------------------+
struct SSpreadFeatures
{
   double                bid;
   double                ask;
   double                spread_price;
   int                   spread_points;
   bool                  spread_acceptable;
   bool                  data_ready;

   void Reset()
   {
      bid               = 0.0;
      ask               = 0.0;
      spread_price      = 0.0;
      spread_points     = 0;
      spread_acceptable = false;
      data_ready        = false;
   }
};

//+------------------------------------------------------------------+
//| Complete feature set for a single timeframe                      |
//+------------------------------------------------------------------+
struct STimeframeFeatures
{
   ENUM_TIMEFRAMES           timeframe;
   string                    timeframe_label;
   datetime                  bar_time;
   SPriceStructure           price;
   SVolatilityFeatures       volatility;
   STrendFeatures            trend;
   SMomentumFeatures         momentum;
   SMarketStructureFeatures  structure;
   SSpreadFeatures           spread;
   bool                      data_ready;

   void Reset()
   {
      timeframe       = PERIOD_CURRENT;
      timeframe_label = "";
      bar_time        = 0;
      price.Reset();
      volatility.Reset();
      trend.Reset();
      momentum.Reset();
      structure.Reset();
      spread.Reset();
      data_ready      = false;
   }
};

//+------------------------------------------------------------------+
//| Multi-timeframe feature composite for a symbol                   |
//+------------------------------------------------------------------+
struct SMultiTimeframeFeatures
{
   string              symbol;
   datetime            evaluation_time;
   bool                overall_data_ready;

   STimeframeFeatures  tf_m1;
   STimeframeFeatures  tf_m5;
   STimeframeFeatures  tf_m15;
   STimeframeFeatures  tf_h1;
   STimeframeFeatures  tf_h4;
   STimeframeFeatures  tf_d1;

   void Reset()
   {
      symbol             = "";
      evaluation_time    = 0;
      overall_data_ready = false;
      tf_m1.Reset();
      tf_m5.Reset();
      tf_m15.Reset();
      tf_h1.Reset();
      tf_h4.Reset();
      tf_d1.Reset();
   }
};

#endif
