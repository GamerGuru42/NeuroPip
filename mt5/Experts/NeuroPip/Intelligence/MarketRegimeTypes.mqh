//+------------------------------------------------------------------+
//| MarketRegimeTypes.mqh                                            |
//| ATG Trading Engine - Phase 3                                     |
//| Market Regime Classification Types and Structures                |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_MARKET_REGIME_TYPES_MQH
#define ATG_MARKET_REGIME_TYPES_MQH

#include "MarketFeatureTypes.mqh"

//+------------------------------------------------------------------+
//| Primary Composite Regime Vocabulary                              |
//+------------------------------------------------------------------+
enum ENUM_ATG_MARKET_REGIME
{
   REGIME_INSUFFICIENT_DATA = 0,
   REGIME_TRENDING_BULLISH,
   REGIME_TRENDING_BEARISH,
   REGIME_RANGING,
   REGIME_HIGH_VOLATILITY,
   REGIME_LOW_VOLATILITY,
   REGIME_TRANSITION
};

//+------------------------------------------------------------------+
//| Multi-dimensional Trend Classification                           |
//+------------------------------------------------------------------+
enum ENUM_REGIME_TREND
{
   REGIME_TREND_UNKNOWN = 0,
   REGIME_TREND_BULLISH,
   REGIME_TREND_BEARISH,
   REGIME_TREND_SIDEWAYS
};

//+------------------------------------------------------------------+
//| Multi-dimensional Volatility Classification                      |
//+------------------------------------------------------------------+
enum ENUM_REGIME_VOLATILITY
{
   REGIME_VOL_UNKNOWN = 0,
   REGIME_VOL_LOW,
   REGIME_VOL_NORMAL,
   REGIME_VOL_HIGH,
   REGIME_VOL_EXTREME
};

//+------------------------------------------------------------------+
//| Multi-dimensional Market Structure Classification                |
//+------------------------------------------------------------------+
enum ENUM_REGIME_STRUCTURE
{
   REGIME_STRUCT_UNKNOWN = 0,
   REGIME_STRUCT_CONSOLIDATION,
   REGIME_STRUCT_EXPANSION,
   REGIME_STRUCT_PULLBACK,
   REGIME_STRUCT_BREAKOUT
};

//+------------------------------------------------------------------+
//| Structured view of condition per timeframe                       |
//+------------------------------------------------------------------+
struct STimeframeRegimeView
{
   ENUM_TIMEFRAMES      timeframe;
   string               role;            // e.g. "SHORT-TERM", "INTRADAY", "PRIMARY TREND", "MACRO"
   ENUM_REGIME_TREND    trend;
   ENUM_REGIME_VOLATILITY volatility;
   ENUM_REGIME_STRUCTURE  structure;
   string               summary;

   void Reset()
   {
      timeframe  = PERIOD_CURRENT;
      role       = "";
      trend      = REGIME_TREND_UNKNOWN;
      volatility = REGIME_VOL_UNKNOWN;
      structure  = REGIME_STRUCT_UNKNOWN;
      summary    = "UNINITIALIZED";
   }
};

//+------------------------------------------------------------------+
//| Complete Regime Classification Record                            |
//+------------------------------------------------------------------+
struct SRegimeClassification
{
   string                   symbol;
   datetime                 evaluated_time;

   // Composite regime label
   ENUM_ATG_MARKET_REGIME   primary_regime;

   // Distinct orthogonal dimensions
   ENUM_REGIME_TREND        trend_dimension;
   ENUM_REGIME_VOLATILITY   vol_dimension;
   ENUM_REGIME_STRUCTURE    struct_dimension;

   // Multi-timeframe perspectives
   STimeframeRegimeView     tf_m1_view;
   STimeframeRegimeView     tf_m5_view;
   STimeframeRegimeView     tf_m15_view;
   STimeframeRegimeView     tf_h1_view;
   STimeframeRegimeView     tf_h4_view;
   STimeframeRegimeView     tf_d1_view;

   // Confidence and reasoning
   double                   confidence;          // 0.0 to 1.0
   string                   regime_name;
   string                   description;
   bool                     is_valid;

   void Reset()
   {
      symbol          = "";
      evaluated_time  = 0;
      primary_regime  = REGIME_INSUFFICIENT_DATA;
      trend_dimension = REGIME_TREND_UNKNOWN;
      vol_dimension   = REGIME_VOL_UNKNOWN;
      struct_dimension= REGIME_STRUCT_UNKNOWN;
      confidence      = 0.0;
      regime_name     = "INSUFFICIENT_DATA";
      description     = "No regime analysis performed.";
      is_valid        = false;
      tf_m1_view.Reset();
      tf_m5_view.Reset();
      tf_m15_view.Reset();
      tf_h1_view.Reset();
      tf_h4_view.Reset();
      tf_d1_view.Reset();
   }
};

//+------------------------------------------------------------------+
//| Convert regime enum to human-readable string                     |
//+------------------------------------------------------------------+
inline string MarketRegimeToString(ENUM_ATG_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_TRENDING_BULLISH: return "TRENDING_BULLISH";
      case REGIME_TRENDING_BEARISH: return "TRENDING_BEARISH";
      case REGIME_RANGING:          return "RANGING";
      case REGIME_HIGH_VOLATILITY:  return "HIGH_VOLATILITY";
      case REGIME_LOW_VOLATILITY:   return "LOW_VOLATILITY";
      case REGIME_TRANSITION:       return "TRANSITION";
      case REGIME_INSUFFICIENT_DATA:return "INSUFFICIENT_DATA";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Convert trend dimension to string                                |
//+------------------------------------------------------------------+
inline string RegimeTrendToString(ENUM_REGIME_TREND trend)
{
   switch(trend)
   {
      case REGIME_TREND_BULLISH:  return "BULLISH";
      case REGIME_TREND_BEARISH:  return "BEARISH";
      case REGIME_TREND_SIDEWAYS: return "SIDEWAYS";
      case REGIME_TREND_UNKNOWN:  return "UNKNOWN";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Convert volatility dimension to string                           |
//+------------------------------------------------------------------+
inline string RegimeVolToString(ENUM_REGIME_VOLATILITY vol)
{
   switch(vol)
   {
      case REGIME_VOL_LOW:     return "LOW";
      case REGIME_VOL_NORMAL:  return "NORMAL";
      case REGIME_VOL_HIGH:    return "HIGH";
      case REGIME_VOL_EXTREME: return "EXTREME";
      case REGIME_VOL_UNKNOWN: return "UNKNOWN";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Convert structure dimension to string                            |
//+------------------------------------------------------------------+
inline string RegimeStructToString(ENUM_REGIME_STRUCTURE str)
{
   switch(str)
   {
      case REGIME_STRUCT_CONSOLIDATION: return "CONSOLIDATION";
      case REGIME_STRUCT_EXPANSION:     return "EXPANSION";
      case REGIME_STRUCT_PULLBACK:      return "PULLBACK";
      case REGIME_STRUCT_BREAKOUT:      return "BREAKOUT";
      case REGIME_STRUCT_UNKNOWN:       return "UNKNOWN";
   }
   return "UNKNOWN";
}

#endif
