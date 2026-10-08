//+------------------------------------------------------------------+
//| SignalEngine.mqh                                                 |
//| NeuroPip - Phase 3                                     |
//| Candidate Signal Analysis & Confluence Evaluation                |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_SIGNAL_ENGINE_MQH
#define ATG_SIGNAL_ENGINE_MQH

#include "MarketFeatureTypes.mqh"
#include "MarketRegimeTypes.mqh"
#include "SignalTypes.mqh"
#include "../Diagnostics/Logger.mqh"

class CSignalEngine
{
private:
   CLogger* m_logger;

   // Minimum confluence threshold for candidate qualification
   double   m_min_candidate_confidence;

   //+----------------------------------------------------------------+
   //| Build formatted explainable text for signal candidate          |
   //+----------------------------------------------------------------+
   void FormatExplanation(SATGSignalCandidate &candidate)
   {
      string exp = StringFormat("=== SIGNAL ANALYSIS: %s ===\n", candidate.symbol);
      exp += StringFormat("Direction: %s | Quality: %s | Bias: %s | Status: %s\n",
         candidate.DirectionToString(),
         candidate.QualityToString(),
         candidate.BiasToString(),
         candidate.StatusToString());
      exp += StringFormat("Confidence: %.2f | Strength: %.2f | Primary TF: %s\n",
         candidate.confidence,
         candidate.strength,
         EnumToString(candidate.primary_timeframe));
      exp += StringFormat("Regime: %s (Trend: %s | Vol: %s | Struct: %s)\n",
         candidate.regime.regime_name,
         RegimeTrendToString(candidate.regime.trend_dimension),
         RegimeVolToString(candidate.regime.vol_dimension),
         RegimeStructToString(candidate.regime.struct_dimension));

      exp += "Evidence:\n";
      int ev_count = ArraySize(candidate.evidence);
      if(ev_count == 0)
         exp += "  - (none)\n";
      else
      {
         for(int i = 0; i < ev_count; i++)
            exp += StringFormat("  + %s\n", candidate.evidence[i]);
      }

      exp += "Conflicts:\n";
      int cf_count = ArraySize(candidate.conflicts);
      if(cf_count == 0)
         exp += "  - (none)\n";
      else
      {
         for(int i = 0; i < cf_count; i++)
            exp += StringFormat("  - %s\n", candidate.conflicts[i]);
      }

      candidate.formatted_explanation = exp;
   }

public:
   CSignalEngine(CLogger* logger)
      : m_logger(logger),
        m_min_candidate_confidence(0.70)
   {
   }

   //+----------------------------------------------------------------+
   //| Analyze market features and regime to evaluate signal candidate|
   //+----------------------------------------------------------------+
   bool Evaluate(const SMultiTimeframeFeatures &mtf,
                 const SRegimeClassification &regime,
                 SATGSignalCandidate &out_candidate)
   {
      out_candidate.Reset();
      out_candidate.symbol            = mtf.symbol;
      out_candidate.primary_timeframe = PERIOD_M15;
      out_candidate.created_time      = TimeCurrent();
      out_candidate.regime            = regime;
      out_candidate.primary_features  = mtf.tf_m15;

      // 1. Data Quality Gate
      if(!mtf.overall_data_ready || !regime.is_valid || regime.primary_regime == REGIME_INSUFFICIENT_DATA)
      {
         out_candidate.bias         = BIAS_INSUFFICIENT_DATA;
         out_candidate.direction    = SIGNAL_DIR_NONE;
         out_candidate.quality      = SIGNAL_QUALITY_NONE;
         out_candidate.status       = SIGNAL_STATUS_NONE;
         out_candidate.confidence   = 0.0;
         out_candidate.strength     = 0.0;
         out_candidate.is_candidate = false;
         out_candidate.is_valid     = false;
         out_candidate.AddConflict("Insufficient market data or regime invalid for analysis.");
         FormatExplanation(out_candidate);
         return false;
      }

      out_candidate.is_valid = true;

      // 2. Market Bias Determination (Macro/Higher Timeframe context)
      bool h4_bull = (mtf.tf_h4.trend.trend_direction == TREND_BULLISH);
      bool h4_bear = (mtf.tf_h4.trend.trend_direction == TREND_BEARISH);
      bool h1_bull = (mtf.tf_h1.trend.trend_direction == TREND_BULLISH);
      bool h1_bear = (mtf.tf_h1.trend.trend_direction == TREND_BEARISH);

      if(h4_bull && h1_bull)
         out_candidate.bias = BIAS_BULLISH;
      else if(h4_bear && h1_bear)
         out_candidate.bias = BIAS_BEARISH;
      else if(h1_bull)
         out_candidate.bias = BIAS_BULLISH;
      else if(h1_bear)
         out_candidate.bias = BIAS_BEARISH;
      else
         out_candidate.bias = BIAS_NEUTRAL;

      // 3. Confluence Scoring & Evidence Gathering
      int bull_evidence = 0;
      int bear_evidence = 0;
      int bull_conflicts = 0;
      int bear_conflicts = 0;

      // Factor A: Primary Trend (H1)
      if(h1_bull)
      {
         bull_evidence++;
         out_candidate.AddEvidence(StringFormat("H1 primary trend is bullish (EMA20=%.5f > EMA50=%.5f)",
            mtf.tf_h1.trend.fast_ma, mtf.tf_h1.trend.slow_ma));
      }
      else if(h1_bear)
      {
         bear_evidence++;
         out_candidate.AddEvidence(StringFormat("H1 primary trend is bearish (EMA20=%.5f < EMA50=%.5f)",
            mtf.tf_h1.trend.fast_ma, mtf.tf_h1.trend.slow_ma));
      }
      else
      {
         bull_conflicts++;
         bear_conflicts++;
         out_candidate.AddConflict("H1 primary trend is flat or undefined");
      }

      // Factor B: Higher Timeframe Trend (H4)
      if(h4_bull)
      {
         bull_evidence++;
         out_candidate.AddEvidence("H4 higher-timeframe trend aligns bullish");
         bear_conflicts++;
      }
      else if(h4_bear)
      {
         bear_evidence++;
         out_candidate.AddEvidence("H4 higher-timeframe trend aligns bearish");
         bull_conflicts++;
      }
      else
      {
         out_candidate.AddConflict("H4 trend lacks clear directional alignment");
      }

      // Factor C: Intraday Market Structure (M15)
      if(mtf.tf_m15.structure.structure_state == STRUCT_HIGHER_HIGHS_LOWS)
      {
         bull_evidence++;
         out_candidate.AddEvidence("M15 market structure forms higher highs and higher lows");
         bear_conflicts++;
      }
      else if(mtf.tf_m15.structure.structure_state == STRUCT_LOWER_HIGHS_LOWS)
      {
         bear_evidence++;
         out_candidate.AddEvidence("M15 market structure forms lower highs and lower lows");
         bull_conflicts++;
      }
      else
      {
         out_candidate.AddConflict("M15 structure is ranging without clean directional swings");
      }

      // Factor D: Momentum & Exhaustion Check (M15 RSI)
      double rsi_m15 = mtf.tf_m15.momentum.rsi;
      if(rsi_m15 > 50.0 && rsi_m15 < 68.0)
      {
         bull_evidence++;
         out_candidate.AddEvidence(StringFormat("M15 RSI (%.1f) confirms healthy bullish momentum without exhaustion", rsi_m15));
      }
      else if(rsi_m15 < 50.0 && rsi_m15 > 32.0)
      {
         bear_evidence++;
         out_candidate.AddEvidence(StringFormat("M15 RSI (%.1f) confirms healthy bearish momentum without exhaustion", rsi_m15));
      }
      else if(rsi_m15 >= 68.0)
      {
         bull_conflicts++;
         out_candidate.AddConflict(StringFormat("M15 RSI (%.1f) in overbought territory (>68) - risk of pullback", rsi_m15));
      }
      else if(rsi_m15 <= 32.0)
      {
         bear_conflicts++;
         out_candidate.AddConflict(StringFormat("M15 RSI (%.1f) in oversold territory (<32) - risk of bounce", rsi_m15));
      }

      // Factor E: Short-Term Confirmation (M5)
      if(mtf.tf_m5.trend.trend_direction == TREND_BULLISH)
      {
         bull_evidence++;
         out_candidate.AddEvidence("M5 short-term trend confirms bullish direction");
      }
      else if(mtf.tf_m5.trend.trend_direction == TREND_BEARISH)
      {
         bear_evidence++;
         out_candidate.AddEvidence("M5 short-term trend confirms bearish direction");
      }
      else
      {
         out_candidate.AddConflict("M5 short-term trend is neutral or diverging");
      }

      // Factor F: Volatility & Spread Health Filter
      if(regime.vol_dimension == REGIME_VOL_EXTREME)
      {
         bull_conflicts += 2;
         bear_conflicts += 2;
         out_candidate.AddConflict("Extreme volatility detected - trade candidate suppressed");
      }
      else if(regime.vol_dimension == REGIME_VOL_NORMAL || regime.vol_dimension == REGIME_VOL_HIGH)
      {
         out_candidate.AddEvidence("Volatility regime within acceptable operating boundaries");
      }

      if(mtf.tf_m15.spread.spread_acceptable)
      {
         out_candidate.AddEvidence(StringFormat("Spread (%d pts) is normal and acceptable", mtf.tf_m15.spread.spread_points));
      }
      else
      {
         bull_conflicts++;
         bear_conflicts++;
         out_candidate.AddConflict(StringFormat("Spread (%d pts) is elevated or unavailable", mtf.tf_m15.spread.spread_points));
      }

      // 4. Confluence Evaluation & Candidate Qualification
      // Max possible evidence score is ~6
      double total_factors = 6.0;
      double bull_score = (double)bull_evidence / total_factors;
      double bear_score = (double)bear_evidence / total_factors;

      // Confluence threshold: need at least 4 evidence points and low conflict
      if(bull_evidence >= 4 && bull_conflicts <= 1 && bull_score >= m_min_candidate_confidence)
      {
         out_candidate.direction    = SIGNAL_DIR_BUY;
         out_candidate.confidence   = MathMin(0.95, bull_score + 0.15);
         out_candidate.strength     = bull_score;
         out_candidate.quality      = (out_candidate.confidence >= 0.85) ?
            SIGNAL_QUALITY_STRONG_CANDIDATE : SIGNAL_QUALITY_CANDIDATE;
         out_candidate.status       = SIGNAL_STATUS_CANDIDATE_ONLY;
         out_candidate.is_candidate = true;
      }
      else if(bear_evidence >= 4 && bear_conflicts <= 1 && bear_score >= m_min_candidate_confidence)
      {
         out_candidate.direction    = SIGNAL_DIR_SELL;
         out_candidate.confidence   = MathMin(0.95, bear_score + 0.15);
         out_candidate.strength     = bear_score;
         out_candidate.quality      = (out_candidate.confidence >= 0.85) ?
            SIGNAL_QUALITY_STRONG_CANDIDATE : SIGNAL_QUALITY_CANDIDATE;
         out_candidate.status       = SIGNAL_STATUS_CANDIDATE_ONLY;
         out_candidate.is_candidate = true;
      }
      else if(bull_evidence >= 3 && bull_evidence > bear_evidence)
      {
         // Market bias exists, but setup lacks full confluence
         out_candidate.direction    = SIGNAL_DIR_NONE;
         out_candidate.confidence   = bull_score;
         out_candidate.strength     = bull_score * 0.7;
         out_candidate.quality      = SIGNAL_QUALITY_WEAK;
         out_candidate.status       = SIGNAL_STATUS_NONE;
         out_candidate.is_candidate = false;
         out_candidate.AddConflict("Setup lacks full confluence threshold (WAIT)");
      }
      else if(bear_evidence >= 3 && bear_evidence > bull_evidence)
      {
         // Market bias exists, but setup lacks full confluence
         out_candidate.direction    = SIGNAL_DIR_NONE;
         out_candidate.confidence   = bear_score;
         out_candidate.strength     = bear_score * 0.7;
         out_candidate.quality      = SIGNAL_QUALITY_WEAK;
         out_candidate.status       = SIGNAL_STATUS_NONE;
         out_candidate.is_candidate = false;
         out_candidate.AddConflict("Setup lacks full confluence threshold (WAIT)");
      }
      else
      {
         // Neutral market or chop
         out_candidate.direction    = SIGNAL_DIR_NONE;
         out_candidate.confidence   = 0.30;
         out_candidate.strength     = 0.20;
         out_candidate.quality      = SIGNAL_QUALITY_NONE;
         out_candidate.status       = SIGNAL_STATUS_NONE;
         out_candidate.is_candidate = false;
         out_candidate.AddConflict("No directional confluence detected - market in consolidation/wait mode");
      }

      FormatExplanation(out_candidate);
      return out_candidate.is_candidate;
   }
};

#endif
