//+------------------------------------------------------------------+
//| StrategyTypes.mqh                                                |
//| ATG Trading Engine - Phase 4                                     |
//| Strategy Decision Engine Types, Enums and Data Contract           |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_STRATEGY_TYPES_MQH
#define ATG_STRATEGY_TYPES_MQH

#include "../Intelligence/MarketFeatureTypes.mqh"
#include "../Intelligence/MarketRegimeTypes.mqh"
#include "../Intelligence/SignalTypes.mqh"

//+------------------------------------------------------------------+
//| Strategy Decision Status                                         |
//| IMPORTANT: STRATEGY_APPROVED means approved as STRATEGY CANDIDATE|
//| It does NOT mean execute trade.                                  |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_DECISION_STATUS
{
   STRATEGY_WAIT = 0,               // Default steady state: observing market, no setup
   STRATEGY_CANDIDATE,              // Meets initial criteria, undergoing validation
   STRATEGY_APPROVED,               // Approved as a strategy candidate (NO EXECUTION)
   STRATEGY_REJECTED,               // Failed one or more validation gates
   STRATEGY_INSUFFICIENT_DATA,      // Insufficient historical bars or invalid metrics
   STRATEGY_EXPIRED                 // Candidate exceeded maximum validity lifetime
};

//+------------------------------------------------------------------+
//| Strategy Validation Gate Result                                  |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_GATE_RESULT
{
   GATE_PASS = 0,
   GATE_WARN,
   GATE_FAIL
};

//+------------------------------------------------------------------+
//| Explicit Rejection Reasons                                       |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_REJECTION_REASON
{
   STRAT_REJECT_NONE = 0,
   STRAT_REJECT_INSUFFICIENT_DATA,
   STRAT_REJECT_REGIME_INCOMPATIBLE,
   STRAT_REJECT_TIMEFRAME_ALIGNMENT,
   STRAT_REJECT_STRUCTURE_INVALID,
   STRAT_REJECT_MOMENTUM_INVALID,
   STRAT_REJECT_VOLATILITY_INVALID,
   STRAT_REJECT_EXCESSIVE_SPREAD,
   STRAT_REJECT_CRITICAL_CONFLICT,
   STRAT_REJECT_CONFIDENCE_BELOW_MIN,
   STRAT_REJECT_CONFLUENCE_BELOW_MIN,
   STRAT_REJECT_DUPLICATE_BAR,
   STRAT_REJECT_UNKNOWN
};

//+------------------------------------------------------------------+
//| Centralized Tunable Strategy Parameters                          |
//+------------------------------------------------------------------+
struct SStrategyParameters
{
   string   strategy_id;
   string   strategy_version;

   double   min_confidence;             // Minimum required confidence threshold (e.g. 0.75)
   double   min_confluence;             // Minimum required deconstructed composite score (e.g. 0.70)
   int      min_timeframe_agreement;    // Minimum aligned timeframes (e.g. 3 of 4: H4, H1, M15, M5)
   int      max_spread_points;          // Maximum allowed spread in points (e.g. 35)
   double   min_atr_points;             // Minimum ATR required to ensure tradable volatility
   double   max_atr_ratio;              // Maximum ATR ratio before declaring extreme volatility (e.g. 1.80)
   double   conflict_penalty_weight;    // Penalty subtracted per conflicting signal (e.g. 0.15)
   int      signal_expiry_sec;          // Time in seconds after which candidate expires (e.g. 3600)

   void Reset()
   {
      strategy_id             = "ATG_TREND_CONTINUATION";
      strategy_version        = "1.0.0";
      min_confidence          = 0.75;
      min_confluence          = 0.70;
      min_timeframe_agreement = 3;
      max_spread_points       = 35;
      min_atr_points          = 8.0;
      max_atr_ratio           = 1.80;
      conflict_penalty_weight = 0.15;
      signal_expiry_sec       = 3600;
   }
};

//+------------------------------------------------------------------+
//| Deconstructed Transparent Confluence Score Breakdown             |
//+------------------------------------------------------------------+
struct SStrategyConfluenceScore
{
   double trend_score;                  // 0.0 to 1.0 (weight: 0.25)
   double structure_score;              // 0.0 to 1.0 (weight: 0.20)
   double momentum_score;               // 0.0 to 1.0 (weight: 0.20)
   double volatility_score;             // 0.0 to 1.0 (weight: 0.15)
   double spread_score;                 // 0.0 to 1.0 (weight: 0.10)
   double timeframe_agreement_score;    // 0.0 to 1.0 (weight: 0.10)
   double conflict_penalty;             // Subtracted penalty based on active conflicts

   double composite_score;              // Final weighted score: 0.0 to 1.0

   void Reset()
   {
      trend_score               = 0.0;
      structure_score           = 0.0;
      momentum_score            = 0.0;
      volatility_score          = 0.0;
      spread_score              = 0.0;
      timeframe_agreement_score = 0.0;
      conflict_penalty          = 0.0;
      composite_score           = 0.0;
   }

   void CalculateComposite()
   {
      double raw = (trend_score * 0.25) +
                   (structure_score * 0.20) +
                   (momentum_score * 0.20) +
                   (volatility_score * 0.15) +
                   (spread_score * 0.10) +
                   (timeframe_agreement_score * 0.10);

      composite_score = MathMax(0.0, raw - conflict_penalty);
      if(composite_score > 1.0)
         composite_score = 1.0;
   }
};

//+------------------------------------------------------------------+
//| Dedicated Strategy Decision Contract                             |
//+------------------------------------------------------------------+
struct SStrategyDecision
{
   ulong                          decision_id;
   string                         symbol;
   ENUM_TIMEFRAMES                primary_timeframe;
   ENUM_ATG_SIGNAL_DIRECTION      direction;
   ENUM_STRATEGY_DECISION_STATUS  status;

   string                         strategy_id;
   string                         strategy_version;

   double                         confidence;
   double                         quality_score;
   SStrategyConfluenceScore       score_breakdown;

   ENUM_ATG_MARKET_REGIME         primary_regime;
   ENUM_ATG_MARKET_BIAS           market_bias;

   string                         supporting_evidence[];
   string                         conflicting_evidence[];

   ENUM_STRATEGY_REJECTION_REASON rejection_reason;
   string                         rejection_detail;

   datetime                       created_time;
   datetime                       bar_time;
   datetime                       expiry_time;

   bool                           is_candidate;
   bool                           is_approved;   // Approved as candidate ONLY

   string                         formatted_explanation;

   void Reset()
   {
      decision_id        = 0;
      symbol             = "";
      primary_timeframe  = PERIOD_CURRENT;
      direction          = SIGNAL_DIR_NONE;
      status             = STRATEGY_WAIT;
      strategy_id        = "ATG_TREND_CONTINUATION";
      strategy_version   = "1.0.0";
      confidence         = 0.0;
      quality_score      = 0.0;
      score_breakdown.Reset();
      primary_regime     = REGIME_INSUFFICIENT_DATA;
      market_bias        = BIAS_NEUTRAL;
      rejection_reason   = STRAT_REJECT_NONE;
      rejection_detail   = "";
      created_time       = 0;
      bar_time           = 0;
      expiry_time        = 0;
      is_candidate       = false;
      is_approved        = false;
      formatted_explanation = "STRATEGY_WAIT: No trade candidate";
      ArrayResize(supporting_evidence, 0);
      ArrayResize(conflicting_evidence, 0);
   }

   void AddEvidence(const string ev)
   {
      int size = ArraySize(supporting_evidence);
      ArrayResize(supporting_evidence, size + 1);
      supporting_evidence[size] = ev;
   }

   void AddConflict(const string cf)
   {
      int size = ArraySize(conflicting_evidence);
      ArrayResize(conflicting_evidence, size + 1);
      conflicting_evidence[size] = cf;
   }

   string StatusToString() const
   {
      switch(status)
      {
         case STRATEGY_WAIT:              return "WAIT";
         case STRATEGY_CANDIDATE:         return "CANDIDATE";
         case STRATEGY_APPROVED:          return "APPROVED_CANDIDATE_ONLY";
         case STRATEGY_REJECTED:          return "REJECTED";
         case STRATEGY_INSUFFICIENT_DATA: return "INSUFFICIENT_DATA";
         case STRATEGY_EXPIRED:           return "EXPIRED";
      }
      return "UNKNOWN";
   }

   string DirectionToString() const
   {
      switch(direction)
      {
         case SIGNAL_DIR_BUY:     return "BUY";
         case SIGNAL_DIR_SELL:    return "SELL";
         case SIGNAL_DIR_NEUTRAL: return "NEUTRAL";
         case SIGNAL_DIR_NONE:    return "NONE";
      }
      return "NONE";
   }

   string RejectionToString() const
   {
      switch(rejection_reason)
      {
         case STRAT_REJECT_NONE:                  return "NONE";
         case STRAT_REJECT_INSUFFICIENT_DATA:     return "INSUFFICIENT_DATA";
         case STRAT_REJECT_REGIME_INCOMPATIBLE:   return "REGIME_INCOMPATIBLE";
         case STRAT_REJECT_TIMEFRAME_ALIGNMENT:   return "TIMEFRAME_ALIGNMENT";
         case STRAT_REJECT_STRUCTURE_INVALID:     return "STRUCTURE_INVALID";
         case STRAT_REJECT_MOMENTUM_INVALID:      return "MOMENTUM_INVALID";
         case STRAT_REJECT_VOLATILITY_INVALID:    return "VOLATILITY_INVALID";
         case STRAT_REJECT_EXCESSIVE_SPREAD:      return "EXCESSIVE_SPREAD";
         case STRAT_REJECT_CRITICAL_CONFLICT:     return "CRITICAL_CONFLICT";
         case STRAT_REJECT_CONFIDENCE_BELOW_MIN:  return "CONFIDENCE_BELOW_MIN";
         case STRAT_REJECT_CONFLUENCE_BELOW_MIN:  return "CONFLUENCE_BELOW_MIN";
         case STRAT_REJECT_DUPLICATE_BAR:         return "DUPLICATE_BAR";
         case STRAT_REJECT_UNKNOWN:               return "UNKNOWN";
      }
      return "UNKNOWN";
   }
};

#endif
