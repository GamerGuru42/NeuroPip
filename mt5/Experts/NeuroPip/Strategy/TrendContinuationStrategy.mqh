//+------------------------------------------------------------------+
//| TrendContinuationStrategy.mqh                                    |
//| ATG Trading Engine - Phase 4                                     |
//| Primary Strategy: ATG_TREND_CONTINUATION                         |
//| Confluence Scoring, Rule Evaluation, Candidate Generation        |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_TREND_CONTINUATION_STRATEGY_MQH
#define ATG_TREND_CONTINUATION_STRATEGY_MQH

#include "StrategyTypes.mqh"
#include "StrategyValidator.mqh"
#include "../Diagnostics/Logger.mqh"

class CTrendContinuationStrategy
{
private:
   CLogger*            m_logger;
   SStrategyParameters m_params;
   CStrategyValidator  m_validator;

   //+----------------------------------------------------------------+
   //| Calculate deconstructed transparent confluence score           |
   //+----------------------------------------------------------------+
   void CalculateScore(const SMultiTimeframeFeatures &mtf,
                       const SRegimeClassification &regime,
                       const SATGSignalCandidate &candidate,
                       SStrategyConfluenceScore &out_score)
   {
      out_score.Reset();

      if(candidate.direction != SIGNAL_DIR_BUY && candidate.direction != SIGNAL_DIR_SELL)
         return;

      bool is_buy = (candidate.direction == SIGNAL_DIR_BUY);

      // 1. Trend Score (weight 0.25)
      double t_score = 0.0;
      if(is_buy)
      {
         if(mtf.tf_h1.trend.trend_direction == TREND_BULLISH) t_score += 0.50;
         if(mtf.tf_h4.trend.trend_direction == TREND_BULLISH) t_score += 0.35;
         if(mtf.tf_h1.trend.ma_slope_points > 0.0)           t_score += 0.15;
      }
      else
      {
         if(mtf.tf_h1.trend.trend_direction == TREND_BEARISH) t_score += 0.50;
         if(mtf.tf_h4.trend.trend_direction == TREND_BEARISH) t_score += 0.35;
         if(mtf.tf_h1.trend.ma_slope_points < 0.0)           t_score += 0.15;
      }
      out_score.trend_score = MathMin(1.0, t_score);

      // 2. Structure Score (weight 0.20)
      double s_score = 0.0;
      if(is_buy)
      {
         if(mtf.tf_m15.structure.structure_state == STRUCT_HIGHER_HIGHS_LOWS) s_score = 1.0;
         else if(mtf.tf_m15.structure.higher_low)                             s_score = 0.70;
         else if(mtf.tf_m15.structure.structure_state == STRUCT_RANGING)     s_score = 0.30;
      }
      else
      {
         if(mtf.tf_m15.structure.structure_state == STRUCT_LOWER_HIGHS_LOWS) s_score = 1.0;
         else if(mtf.tf_m15.structure.lower_high)                             s_score = 0.70;
         else if(mtf.tf_m15.structure.structure_state == STRUCT_RANGING)     s_score = 0.30;
      }
      out_score.structure_score = s_score;

      // 3. Momentum Score (weight 0.20)
      double m_score = 0.0;
      double rsi = mtf.tf_m15.momentum.rsi;
      if(is_buy)
      {
         if(rsi >= 52.0 && rsi <= 65.0)      m_score = 1.0;
         else if(rsi >= 48.0 && rsi < 52.0)  m_score = 0.70;
         else if(rsi > 65.0 && rsi < 70.0)   m_score = 0.60;
         else                                m_score = 0.20;
      }
      else
      {
         if(rsi >= 35.0 && rsi <= 48.0)      m_score = 1.0;
         else if(rsi > 48.0 && rsi <= 52.0)  m_score = 0.70;
         else if(rsi >= 30.0 && rsi < 35.0)  m_score = 0.60;
         else                                m_score = 0.20;
      }
      out_score.momentum_score = m_score;

      // 4. Volatility Score (weight 0.15)
      double v_ratio = mtf.tf_m15.volatility.atr_ratio_to_avg;
      double v_score = 0.0;
      if(v_ratio >= 0.85 && v_ratio <= 1.25)     v_score = 1.0;
      else if(v_ratio > 1.25 && v_ratio <= 1.45) v_score = 0.75;
      else if(v_ratio >= 0.70 && v_ratio < 0.85) v_score = 0.60;
      else                                       v_score = 0.30;
      out_score.volatility_score = v_score;

      // 5. Spread Score (weight 0.10)
      int spread = mtf.tf_m15.spread.spread_points;
      double sp_score = 1.0 - ((double)spread / (double)(m_params.max_spread_points > 0 ? m_params.max_spread_points : 35));
      out_score.spread_score = MathMax(0.0, MathMin(1.0, sp_score));

      // 6. Timeframe Agreement Score (weight 0.10)
      int agreement = 0;
      if((is_buy && mtf.tf_h4.trend.trend_direction == TREND_BULLISH) || (!is_buy && mtf.tf_h4.trend.trend_direction == TREND_BEARISH)) agreement++;
      if((is_buy && mtf.tf_h1.trend.trend_direction == TREND_BULLISH) || (!is_buy && mtf.tf_h1.trend.trend_direction == TREND_BEARISH)) agreement++;
      if((is_buy && mtf.tf_m15.trend.trend_direction == TREND_BULLISH) || (!is_buy && mtf.tf_m15.trend.trend_direction == TREND_BEARISH)) agreement++;
      if((is_buy && mtf.tf_m5.trend.trend_direction == TREND_BULLISH) || (!is_buy && mtf.tf_m5.trend.trend_direction == TREND_BEARISH)) agreement++;
      out_score.timeframe_agreement_score = (double)agreement / 4.0;

      // 7. Conflict Penalty
      int conflict_count = ArraySize(candidate.conflicts);
      out_score.conflict_penalty = conflict_count * m_params.conflict_penalty_weight;

      // Calculate composite
      out_score.CalculateComposite();
   }

   //+----------------------------------------------------------------+
   //| Build formatted explanation for decision output                |
   //+----------------------------------------------------------------+
   void FormatExplanation(SStrategyDecision &decision)
   {
      string exp = StringFormat("=== STRATEGY DECISION: %s [%s] ===\n", decision.strategy_id, decision.symbol);
      exp += StringFormat("Direction: %s | Status: %s | Rejection: %s\n",
         decision.DirectionToString(),
         decision.StatusToString(),
         decision.RejectionToString());
      exp += StringFormat("Confidence: %.2f | Quality Score: %.2f | Composite: %.2f\n",
         decision.confidence,
         decision.quality_score,
         decision.score_breakdown.composite_score);
      exp += StringFormat("Score Breakdown -> Trend: %.2f | Struct: %.2f | Mom: %.2f | Vol: %.2f | Spread: %.2f | TF: %.2f | Penalty: %.2f\n",
         decision.score_breakdown.trend_score,
         decision.score_breakdown.structure_score,
         decision.score_breakdown.momentum_score,
         decision.score_breakdown.volatility_score,
         decision.score_breakdown.spread_score,
         decision.score_breakdown.timeframe_agreement_score,
         decision.score_breakdown.conflict_penalty);
      exp += StringFormat("Regime: %s | Bias: %s\n",
         EnumToString(decision.primary_regime),
         EnumToString(decision.market_bias));

      exp += "Supporting Evidence:\n";
      int ev_count = ArraySize(decision.supporting_evidence);
      if(ev_count == 0)
         exp += "  - (none)\n";
      else
      {
         for(int i = 0; i < ev_count; i++)
            exp += StringFormat("  + %s\n", decision.supporting_evidence[i]);
      }

      exp += "Conflicts / Rejections:\n";
      int cf_count = ArraySize(decision.conflicting_evidence);
      if(cf_count == 0)
         exp += "  - (none)\n";
      else
      {
         for(int i = 0; i < cf_count; i++)
            exp += StringFormat("  - %s\n", decision.conflicting_evidence[i]);
      }

      exp += "Execution Authorization: NOT AUTHORIZED (PHASE 4 CANDIDATE ONLY)\n";
      decision.formatted_explanation = exp;
   }

public:
   CTrendContinuationStrategy(CLogger* logger)
      : m_logger(logger),
        m_validator(logger)
   {
      m_params.Reset();
   }

   // Parameter access
   SStrategyParameters GetParameters() const { return m_params; }
   void GetParameters(SStrategyParameters &out_params) const { out_params = m_params; }
   void SetParameters(const SStrategyParameters &p) { m_params = p; }

   //+----------------------------------------------------------------+
   //| Evaluate candidate through Trend Continuation Strategy         |
   //+----------------------------------------------------------------+
   bool Evaluate(const SMultiTimeframeFeatures &mtf,
                 const SRegimeClassification &regime,
                 const SATGSignalCandidate &candidate,
                 ulong decision_id,
                 SStrategyDecision &out_decision)
   {
      out_decision.Reset();
      out_decision.decision_id       = decision_id;
      out_decision.symbol            = mtf.symbol;
      out_decision.primary_timeframe = PERIOD_M15;
      out_decision.direction         = candidate.direction;
      out_decision.strategy_id       = m_params.strategy_id;
      out_decision.strategy_version  = m_params.strategy_version;
      out_decision.primary_regime    = regime.primary_regime;
      out_decision.market_bias       = candidate.bias;
      out_decision.created_time      = TimeCurrent();
      out_decision.bar_time          = mtf.tf_m15.bar_time;
      out_decision.expiry_time       = out_decision.created_time + m_params.signal_expiry_sec;
      out_decision.confidence        = candidate.confidence;

      // 1. If Phase 3 produced NO_SIGNAL or neutral, return STRATEGY_WAIT immediately
      if(!candidate.is_candidate || candidate.direction == SIGNAL_DIR_NONE || candidate.direction == SIGNAL_DIR_NEUTRAL)
      {
         out_decision.status = STRATEGY_WAIT;
         out_decision.rejection_reason = STRAT_REJECT_NONE;
         out_decision.rejection_detail = "Waiting for Phase 3 confluence setup.";
         FormatExplanation(out_decision);
         return false;
      }

      out_decision.status = STRATEGY_CANDIDATE;
      out_decision.is_candidate = true;

      // Copy forward candidate evidence
      for(int i = 0; i < ArraySize(candidate.evidence); i++)
         out_decision.AddEvidence(candidate.evidence[i]);

      // 2. Calculate transparent confluence score
      CalculateScore(mtf, regime, candidate, out_decision.score_breakdown);
      out_decision.quality_score = out_decision.score_breakdown.composite_score;

      // 3. Validate Strategy Quality Gates
      bool gates_passed = m_validator.ValidateGates(mtf, regime, candidate, m_params, out_decision.score_breakdown, out_decision);

      if(!gates_passed)
      {
         out_decision.status      = STRATEGY_REJECTED;
         out_decision.is_approved = false;
         FormatExplanation(out_decision);
         return false;
      }

      // 4. Candidate Approved (STRATEGY CANDIDATE ONLY)
      out_decision.status       = STRATEGY_APPROVED;
      out_decision.is_approved  = true;
      out_decision.AddEvidence("ALL STRATEGY QUALITY GATES PASSED: Approved as STRATEGY CANDIDATE.");
      FormatExplanation(out_decision);

      return true;
   }
};

#endif
