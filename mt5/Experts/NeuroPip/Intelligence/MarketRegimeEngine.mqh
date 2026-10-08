//+------------------------------------------------------------------+
//| MarketRegimeEngine.mqh                                           |
//| ATG Trading Engine - Phase 3                                     |
//| Market Regime Classification Engine                              |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_MARKET_REGIME_ENGINE_MQH
#define ATG_MARKET_REGIME_ENGINE_MQH

#include "MarketFeatureTypes.mqh"
#include "MarketRegimeTypes.mqh"
#include "../Diagnostics/Logger.mqh"

class CMarketRegimeEngine
{
private:
   CLogger* m_logger;

   //+----------------------------------------------------------------+
   //| Classify a single timeframe's regime perspective              |
   //+----------------------------------------------------------------+
   void ClassifyTimeframeView(const STimeframeFeatures &tf,
                              const string role,
                              STimeframeRegimeView &view)
   {
      view.Reset();
      view.timeframe = tf.timeframe;
      view.role      = role;

      if(!tf.data_ready)
      {
         view.summary = "INSUFFICIENT_DATA";
         return;
      }

      // Trend
      if(tf.trend.trend_direction == TREND_BULLISH)
         view.trend = REGIME_TREND_BULLISH;
      else if(tf.trend.trend_direction == TREND_BEARISH)
         view.trend = REGIME_TREND_BEARISH;
      else
         view.trend = REGIME_TREND_SIDEWAYS;

      // Volatility
      if(tf.volatility.vol_state == VOL_HIGH)
         view.volatility = REGIME_VOL_HIGH;
      else if(tf.volatility.vol_state == VOL_LOW)
         view.volatility = REGIME_VOL_LOW;
      else
         view.volatility = REGIME_VOL_NORMAL;

      // Structure
      if(tf.structure.structure_state == STRUCT_HIGHER_HIGHS_LOWS ||
         tf.structure.structure_state == STRUCT_LOWER_HIGHS_LOWS)
      {
         view.structure = REGIME_STRUCT_EXPANSION;
      }
      else
      {
         view.structure = REGIME_STRUCT_CONSOLIDATION;
      }

      view.summary = StringFormat("%s: %s | %s Vol | %s",
         role,
         RegimeTrendToString(view.trend),
         RegimeVolToString(view.volatility),
         RegimeStructToString(view.structure));
   }

public:
   CMarketRegimeEngine(CLogger* logger)
      : m_logger(logger)
   {
   }

   //+----------------------------------------------------------------+
   //| Classify composite and multi-dimensional regimes               |
   //+----------------------------------------------------------------+
   bool Classify(const SMultiTimeframeFeatures &mtf,
                 SRegimeClassification &out_regime)
   {
      out_regime.Reset();
      out_regime.symbol         = mtf.symbol;
      out_regime.evaluated_time = TimeCurrent();

      // Guard: Insufficient data check
      if(!mtf.overall_data_ready)
      {
         out_regime.primary_regime  = REGIME_INSUFFICIENT_DATA;
         out_regime.regime_name     = "INSUFFICIENT_DATA";
         out_regime.description     = "Required multi-timeframe bar data not yet available.";
         out_regime.confidence      = 0.0;
         out_regime.is_valid        = false;
         return false;
      }

      // 1. Build individual timeframe views
      ClassifyTimeframeView(mtf.tf_m1,  "M1 SHORT-TERM",    out_regime.tf_m1_view);
      ClassifyTimeframeView(mtf.tf_m5,  "M5 SHORT-TERM",    out_regime.tf_m5_view);
      ClassifyTimeframeView(mtf.tf_m15, "M15 INTRADAY",     out_regime.tf_m15_view);
      ClassifyTimeframeView(mtf.tf_h1,  "H1 PRIMARY TREND", out_regime.tf_h1_view);
      ClassifyTimeframeView(mtf.tf_h4,  "H4 HIGHER TREND",  out_regime.tf_h4_view);
      ClassifyTimeframeView(mtf.tf_d1,  "D1 MACRO CONTEXT", out_regime.tf_d1_view);

      // 2. Trend Dimension (synthesizes H4 and H1)
      bool h1_bull = (mtf.tf_h1.trend.trend_direction == TREND_BULLISH);
      bool h1_bear = (mtf.tf_h1.trend.trend_direction == TREND_BEARISH);
      bool h4_bull = (mtf.tf_h4.trend.trend_direction == TREND_BULLISH);
      bool h4_bear = (mtf.tf_h4.trend.trend_direction == TREND_BEARISH);

      if(h1_bull && h4_bull)
         out_regime.trend_dimension = REGIME_TREND_BULLISH;
      else if(h1_bear && h4_bear)
         out_regime.trend_dimension = REGIME_TREND_BEARISH;
      else if((h1_bull && h4_bear) || (h1_bear && h4_bull))
         out_regime.trend_dimension = REGIME_TREND_SIDEWAYS; // opposing higher/lower trends
      else if(h1_bull || h4_bull)
         out_regime.trend_dimension = REGIME_TREND_BULLISH;
      else if(h1_bear || h4_bear)
         out_regime.trend_dimension = REGIME_TREND_BEARISH;
      else
         out_regime.trend_dimension = REGIME_TREND_SIDEWAYS;

      // 3. Volatility Dimension (M15 & H1 ATR metrics)
      double m15_ratio = mtf.tf_m15.volatility.atr_ratio_to_avg;
      double h1_ratio  = mtf.tf_h1.volatility.atr_ratio_to_avg;
      double avg_ratio = (m15_ratio + h1_ratio) / 2.0;

      if(avg_ratio > 1.8)
         out_regime.vol_dimension = REGIME_VOL_EXTREME;
      else if(avg_ratio > 1.3)
         out_regime.vol_dimension = REGIME_VOL_HIGH;
      else if(avg_ratio < 0.72)
         out_regime.vol_dimension = REGIME_VOL_LOW;
      else
         out_regime.vol_dimension = REGIME_VOL_NORMAL;

      // 4. Structure Dimension (M15 & H1 structure)
      if(mtf.tf_m15.structure.structure_state == STRUCT_HIGHER_HIGHS_LOWS)
      {
         out_regime.struct_dimension = (out_regime.trend_dimension == REGIME_TREND_BULLISH) ?
            REGIME_STRUCT_EXPANSION : REGIME_STRUCT_PULLBACK;
      }
      else if(mtf.tf_m15.structure.structure_state == STRUCT_LOWER_HIGHS_LOWS)
      {
         out_regime.struct_dimension = (out_regime.trend_dimension == REGIME_TREND_BEARISH) ?
            REGIME_STRUCT_EXPANSION : REGIME_STRUCT_PULLBACK;
      }
      else
      {
         out_regime.struct_dimension = REGIME_STRUCT_CONSOLIDATION;
      }

      // 5. Composite Primary Regime Classification
      // Transition condition: H1 and H4 disagree strongly
      bool is_transition = (h1_bull && h4_bear) || (h1_bear && h4_bull);

      if(out_regime.vol_dimension == REGIME_VOL_EXTREME)
      {
         out_regime.primary_regime = REGIME_HIGH_VOLATILITY;
         out_regime.confidence     = 0.80;
         out_regime.description    = "Extreme volatility detected across active timeframes.";
      }
      else if(is_transition)
      {
         out_regime.primary_regime = REGIME_TRANSITION;
         out_regime.confidence     = 0.60;
         out_regime.description    = "Timeframe trend disagreement (H1 vs H4) indicating potential transition.";
      }
      else if(out_regime.trend_dimension == REGIME_TREND_BULLISH &&
              out_regime.struct_dimension != REGIME_STRUCT_CONSOLIDATION)
      {
         out_regime.primary_regime = REGIME_TRENDING_BULLISH;
         out_regime.confidence     = (h1_bull && h4_bull) ? 0.85 : 0.70;
         out_regime.description    = "Bullish trend supported by multi-timeframe alignment and structure.";
      }
      else if(out_regime.trend_dimension == REGIME_TREND_BEARISH &&
              out_regime.struct_dimension != REGIME_STRUCT_CONSOLIDATION)
      {
         out_regime.primary_regime = REGIME_TRENDING_BEARISH;
         out_regime.confidence     = (h1_bear && h4_bear) ? 0.85 : 0.70;
         out_regime.description    = "Bearish trend supported by multi-timeframe alignment and structure.";
      }
      else if(out_regime.vol_dimension == REGIME_VOL_LOW)
      {
         out_regime.primary_regime = REGIME_LOW_VOLATILITY;
         out_regime.confidence     = 0.75;
         out_regime.description    = "Low volatility consolidation with compressed ATR.";
      }
      else
      {
         out_regime.primary_regime = REGIME_RANGING;
         out_regime.confidence     = 0.70;
         out_regime.description    = "Sideways range-bound price action with no clear trend leadership.";
      }

      out_regime.regime_name = MarketRegimeToString(out_regime.primary_regime);
      out_regime.is_valid    = true;

      return true;
   }
};

#endif
