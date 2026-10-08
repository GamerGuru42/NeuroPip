//+------------------------------------------------------------------+
//| StrategyValidator.mqh                                            |
//| ATG Trading Engine - Phase 4                                     |
//| Multi-Gate Strategy Validation Framework                         |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_STRATEGY_VALIDATOR_MQH
#define ATG_STRATEGY_VALIDATOR_MQH

#include "StrategyTypes.mqh"
#include "../Diagnostics/Logger.mqh"

class CStrategyValidator
{
private:
   CLogger* m_logger;

public:
   CStrategyValidator(CLogger* logger)
      : m_logger(logger)
   {
   }

   //+----------------------------------------------------------------+
   //| Validate all explicit strategy quality gates                   |
   //+----------------------------------------------------------------+
   bool ValidateGates(const SMultiTimeframeFeatures &mtf,
                      const SRegimeClassification &regime,
                      const SATGSignalCandidate &candidate,
                      const SStrategyParameters &params,
                      const SStrategyConfluenceScore &score,
                      SStrategyDecision &out_decision)
   {
      // GATE 1: DATA_VALID
      if(!mtf.overall_data_ready || !regime.is_valid || !candidate.is_valid)
      {
         out_decision.rejection_reason = STRAT_REJECT_INSUFFICIENT_DATA;
         out_decision.rejection_detail = "Gate 1 (DATA_VALID): Missing or incomplete multi-timeframe bar data.";
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      // Direction check
      if(candidate.direction != SIGNAL_DIR_BUY && candidate.direction != SIGNAL_DIR_SELL)
      {
         out_decision.rejection_reason = STRAT_REJECT_NONE;
         out_decision.rejection_detail = "Gate 1: Neutral or no direction from signal foundation.";
         return false;
      }

      // GATE 2: REGIME_COMPATIBLE
      // Trend continuation requires a compatible trending regime
      if(regime.primary_regime == REGIME_INSUFFICIENT_DATA)
      {
         out_decision.rejection_reason = STRAT_REJECT_INSUFFICIENT_DATA;
         out_decision.rejection_detail = "Gate 2 (REGIME_COMPATIBLE): Regime is INSUFFICIENT_DATA.";
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      if(regime.primary_regime == REGIME_RANGING)
      {
         out_decision.rejection_reason = STRAT_REJECT_REGIME_INCOMPATIBLE;
         out_decision.rejection_detail = "Gate 2 (REGIME_COMPATIBLE): RANGING regime incompatible with trend continuation.";
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      if(regime.primary_regime == REGIME_LOW_VOLATILITY)
      {
         out_decision.rejection_reason = STRAT_REJECT_REGIME_INCOMPATIBLE;
         out_decision.rejection_detail = "Gate 2 (REGIME_COMPATIBLE): LOW_VOLATILITY regime; setup lacks sufficient movement.";
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      if(candidate.direction == SIGNAL_DIR_BUY && regime.trend_dimension == REGIME_TREND_BEARISH)
      {
         out_decision.rejection_reason = STRAT_REJECT_REGIME_INCOMPATIBLE;
         out_decision.rejection_detail = "Gate 2 (REGIME_COMPATIBLE): BUY candidate contradicts BEARISH regime trend.";
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      if(candidate.direction == SIGNAL_DIR_SELL && regime.trend_dimension == REGIME_TREND_BULLISH)
      {
         out_decision.rejection_reason = STRAT_REJECT_REGIME_INCOMPATIBLE;
         out_decision.rejection_detail = "Gate 2 (REGIME_COMPATIBLE): SELL candidate contradicts BULLISH regime trend.";
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      // High volatility regime requires strict spread & valid structure
      if(regime.vol_dimension == REGIME_VOL_HIGH)
      {
         if(mtf.tf_m15.spread.spread_points > (params.max_spread_points / 2))
         {
            out_decision.rejection_reason = STRAT_REJECT_VOLATILITY_INVALID;
            out_decision.rejection_detail = "Gate 2 (REGIME_COMPATIBLE): HIGH_VOLATILITY regime combined with wide spread.";
            out_decision.AddConflict(out_decision.rejection_detail);
            return false;
         }
         out_decision.AddEvidence("High volatility regime detected but validated against strict spread tolerances.");
      }

      // GATE 3: TIMEFRAME_ALIGNMENT
      // Check H4 macro and H1 primary trend against direction
      bool h4_align = (candidate.direction == SIGNAL_DIR_BUY && mtf.tf_h4.trend.trend_direction == TREND_BULLISH) ||
                      (candidate.direction == SIGNAL_DIR_SELL && mtf.tf_h4.trend.trend_direction == TREND_BEARISH);

      bool h1_align = (candidate.direction == SIGNAL_DIR_BUY && mtf.tf_h1.trend.trend_direction == TREND_BULLISH) ||
                      (candidate.direction == SIGNAL_DIR_SELL && mtf.tf_h1.trend.trend_direction == TREND_BEARISH);

      bool m15_align = (candidate.direction == SIGNAL_DIR_BUY && mtf.tf_m15.trend.trend_direction == TREND_BULLISH) ||
                       (candidate.direction == SIGNAL_DIR_SELL && mtf.tf_m15.trend.trend_direction == TREND_BEARISH);

      bool m5_align = (candidate.direction == SIGNAL_DIR_BUY && mtf.tf_m5.trend.trend_direction == TREND_BULLISH) ||
                      (candidate.direction == SIGNAL_DIR_SELL && mtf.tf_m5.trend.trend_direction == TREND_BEARISH);

      // Higher timeframe (H4) cannot directly oppose trade direction
      bool h4_opposing = (candidate.direction == SIGNAL_DIR_BUY && mtf.tf_h4.trend.trend_direction == TREND_BEARISH) ||
                         (candidate.direction == SIGNAL_DIR_SELL && mtf.tf_h4.trend.trend_direction == TREND_BULLISH);
      if(h4_opposing)
      {
         out_decision.rejection_reason = STRAT_REJECT_TIMEFRAME_ALIGNMENT;
         out_decision.rejection_detail = "Gate 3 (TIMEFRAME_ALIGNMENT): H4 macro trend directly opposes candidate direction.";
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      // Primary H1 trend must match direction
      if(!h1_align)
      {
         out_decision.rejection_reason = STRAT_REJECT_TIMEFRAME_ALIGNMENT;
         out_decision.rejection_detail = "Gate 3 (TIMEFRAME_ALIGNMENT): H1 primary trend is not aligned with candidate direction.";
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      int aligned_count = (h4_align ? 1 : 0) + (h1_align ? 1 : 0) + (m15_align ? 1 : 0) + (m5_align ? 1 : 0);
      if(aligned_count < params.min_timeframe_agreement)
      {
         out_decision.rejection_reason = STRAT_REJECT_TIMEFRAME_ALIGNMENT;
         out_decision.rejection_detail = StringFormat("Gate 3 (TIMEFRAME_ALIGNMENT): Only %d/4 timeframes aligned (minimum %d required).",
            aligned_count, params.min_timeframe_agreement);
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }
      out_decision.AddEvidence(StringFormat("Timeframe agreement verified: %d/4 timeframes aligned with %s.",
         aligned_count, candidate.DirectionToString()));

      // GATE 4: STRUCTURE_VALID
      if(candidate.direction == SIGNAL_DIR_BUY)
      {
         if(mtf.tf_m15.structure.structure_state == STRUCT_LOWER_HIGHS_LOWS)
         {
            out_decision.rejection_reason = STRAT_REJECT_STRUCTURE_INVALID;
            out_decision.rejection_detail = "Gate 4 (STRUCTURE_VALID): M15 structure shows Lower-Highs/Lower-Lows against BUY.";
            out_decision.AddConflict(out_decision.rejection_detail);
            return false;
         }
         out_decision.AddEvidence("M15 market structure supports bullish continuation.");
      }
      else if(candidate.direction == SIGNAL_DIR_SELL)
      {
         if(mtf.tf_m15.structure.structure_state == STRUCT_HIGHER_HIGHS_LOWS)
         {
            out_decision.rejection_reason = STRAT_REJECT_STRUCTURE_INVALID;
            out_decision.rejection_detail = "Gate 4 (STRUCTURE_VALID): M15 structure shows Higher-Highs/Higher-Lows against SELL.";
            out_decision.AddConflict(out_decision.rejection_detail);
            return false;
         }
         out_decision.AddEvidence("M15 market structure supports bearish continuation.");
      }

      // GATE 5: MOMENTUM_VALID
      if(candidate.direction == SIGNAL_DIR_BUY)
      {
         if(mtf.tf_m15.momentum.is_overbought || mtf.tf_m15.momentum.rsi >= 70.0)
         {
            out_decision.rejection_reason = STRAT_REJECT_MOMENTUM_INVALID;
            out_decision.rejection_detail = StringFormat("Gate 5 (MOMENTUM_VALID): M15 RSI (%.1f) is overbought (>= 70.0).", mtf.tf_m15.momentum.rsi);
            out_decision.AddConflict(out_decision.rejection_detail);
            return false;
         }
         if(mtf.tf_m15.momentum.rsi < 45.0)
         {
            out_decision.rejection_reason = STRAT_REJECT_MOMENTUM_INVALID;
            out_decision.rejection_detail = StringFormat("Gate 5 (MOMENTUM_VALID): M15 RSI (%.1f) below bullish threshold (45.0).", mtf.tf_m15.momentum.rsi);
            out_decision.AddConflict(out_decision.rejection_detail);
            return false;
         }
         out_decision.AddEvidence(StringFormat("M15 RSI (%.1f) confirms bullish momentum in non-overbought zone.", mtf.tf_m15.momentum.rsi));
      }
      else if(candidate.direction == SIGNAL_DIR_SELL)
      {
         if(mtf.tf_m15.momentum.is_oversold || mtf.tf_m15.momentum.rsi <= 30.0)
         {
            out_decision.rejection_reason = STRAT_REJECT_MOMENTUM_INVALID;
            out_decision.rejection_detail = StringFormat("Gate 5 (MOMENTUM_VALID): M15 RSI (%.1f) is oversold (<= 30.0).", mtf.tf_m15.momentum.rsi);
            out_decision.AddConflict(out_decision.rejection_detail);
            return false;
         }
         if(mtf.tf_m15.momentum.rsi > 55.0)
         {
            out_decision.rejection_reason = STRAT_REJECT_MOMENTUM_INVALID;
            out_decision.rejection_detail = StringFormat("Gate 5 (MOMENTUM_VALID): M15 RSI (%.1f) above bearish threshold (55.0).", mtf.tf_m15.momentum.rsi);
            out_decision.AddConflict(out_decision.rejection_detail);
            return false;
         }
         out_decision.AddEvidence(StringFormat("M15 RSI (%.1f) confirms bearish momentum in non-oversold zone.", mtf.tf_m15.momentum.rsi));
      }

      // GATE 6: VOLATILITY_VALID
      if(mtf.tf_m15.volatility.atr_points < params.min_atr_points)
      {
         out_decision.rejection_reason = STRAT_REJECT_VOLATILITY_INVALID;
         out_decision.rejection_detail = StringFormat("Gate 6 (VOLATILITY_VALID): M15 ATR (%.1f pts) below min required (%.1f pts).",
            mtf.tf_m15.volatility.atr_points, params.min_atr_points);
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }
      if(mtf.tf_m15.volatility.atr_ratio_to_avg > params.max_atr_ratio)
      {
         out_decision.rejection_reason = STRAT_REJECT_VOLATILITY_INVALID;
         out_decision.rejection_detail = StringFormat("Gate 6 (VOLATILITY_VALID): M15 ATR ratio (%.2f) exceeds max allowed (%.2f).",
            mtf.tf_m15.volatility.atr_ratio_to_avg, params.max_atr_ratio);
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }
      out_decision.AddEvidence(StringFormat("Volatility acceptable: M15 ATR %.1f pts (Ratio: %.2f).",
         mtf.tf_m15.volatility.atr_points, mtf.tf_m15.volatility.atr_ratio_to_avg));

      // GATE 7: SPREAD_VALID
      if(mtf.tf_m15.spread.spread_points > params.max_spread_points)
      {
         out_decision.rejection_reason = STRAT_REJECT_EXCESSIVE_SPREAD;
         out_decision.rejection_detail = StringFormat("Gate 7 (SPREAD_VALID): Spread (%d pts) exceeds max allowed (%d pts).",
            mtf.tf_m15.spread.spread_points, params.max_spread_points);
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }
      out_decision.AddEvidence(StringFormat("Spread acceptable: %d pts <= %d pts limit.",
         mtf.tf_m15.spread.spread_points, params.max_spread_points));

      // GATE 8: CONFLICT_CHECK
      // Check for conflicts recorded in candidate
      int conflict_count = ArraySize(candidate.conflicts);
      if(conflict_count > 1)
      {
         out_decision.rejection_reason = STRAT_REJECT_CRITICAL_CONFLICT;
         out_decision.rejection_detail = StringFormat("Gate 8 (CONFLICT_CHECK): Multiple (%d) conflicts identified.", conflict_count);
         for(int i = 0; i < conflict_count; i++)
            out_decision.AddConflict(candidate.conflicts[i]);
         return false;
      }

      // GATE 9: CONFIDENCE & CONFLUENCE THRESHOLDS
      if(candidate.confidence < params.min_confidence)
      {
         out_decision.rejection_reason = STRAT_REJECT_CONFIDENCE_BELOW_MIN;
         out_decision.rejection_detail = StringFormat("Gate 9 (CONFIDENCE): Confidence (%.2f) below min required (%.2f).",
            candidate.confidence, params.min_confidence);
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      if(score.composite_score < params.min_confluence)
      {
         out_decision.rejection_reason = STRAT_REJECT_CONFLUENCE_BELOW_MIN;
         out_decision.rejection_detail = StringFormat("Gate 9 (CONFLUENCE): Composite score (%.2f) below min required (%.2f).",
            score.composite_score, params.min_confluence);
         out_decision.AddConflict(out_decision.rejection_detail);
         return false;
      }

      out_decision.AddEvidence(StringFormat("Confluence thresholds passed: Conf=%.2f, ConfluenceScore=%.2f.",
         candidate.confidence, score.composite_score));

      out_decision.rejection_reason = STRAT_REJECT_NONE;
      out_decision.rejection_detail = "";
      return true;
   }
};

#endif
