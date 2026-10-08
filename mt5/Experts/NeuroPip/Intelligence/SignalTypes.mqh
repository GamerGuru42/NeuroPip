//+------------------------------------------------------------------+
//| SignalTypes.mqh                                                  |
//| NeuroPip - Phase 3                                     |
//| Signal Foundation Types, Enums and Candidate Contract            |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_SIGNAL_TYPES_MQH
#define ATG_SIGNAL_TYPES_MQH

#include "MarketFeatureTypes.mqh"
#include "MarketRegimeTypes.mqh"

//+------------------------------------------------------------------+
//| Candidate Signal Direction                                       |
//+------------------------------------------------------------------+
enum ENUM_ATG_SIGNAL_DIRECTION
{
   SIGNAL_DIR_NONE = 0,
   SIGNAL_DIR_BUY,
   SIGNAL_DIR_SELL,
   SIGNAL_DIR_NEUTRAL
};

//+------------------------------------------------------------------+
//| Candidate Signal Quality / Confluence Level                      |
//+------------------------------------------------------------------+
enum ENUM_ATG_SIGNAL_QUALITY
{
   SIGNAL_QUALITY_NONE = 0,
   SIGNAL_QUALITY_WEAK,
   SIGNAL_QUALITY_CANDIDATE,
   SIGNAL_QUALITY_STRONG_CANDIDATE
};

//+------------------------------------------------------------------+
//| Overall Market Bias (distinct from actionable candidate)         |
//+------------------------------------------------------------------+
enum ENUM_ATG_MARKET_BIAS
{
   BIAS_INSUFFICIENT_DATA = 0,
   BIAS_NEUTRAL,
   BIAS_BULLISH,
   BIAS_BEARISH
};

//+------------------------------------------------------------------+
//| Signal Lifecycle Status                                          |
//| STRICT PHASE 3 BOUNDARY: Only CANDIDATE_ONLY or NONE permitted   |
//+------------------------------------------------------------------+
enum ENUM_ATG_SIGNAL_STATUS
{
   SIGNAL_STATUS_NONE = 0,
   SIGNAL_STATUS_CANDIDATE_ONLY,
   SIGNAL_STATUS_REJECTED
};

//+------------------------------------------------------------------+
//| Structured Signal Candidate Record                               |
//+------------------------------------------------------------------+
struct SATGSignalCandidate
{
   string                     symbol;
   ENUM_TIMEFRAMES            primary_timeframe;
   datetime                   created_time;

   // Direction and Quality
   ENUM_ATG_SIGNAL_DIRECTION  direction;
   ENUM_ATG_SIGNAL_QUALITY    quality;
   ENUM_ATG_MARKET_BIAS       bias;
   ENUM_ATG_SIGNAL_STATUS     status;

   // Metrics
   double                     confidence;       // 0.0 to 1.0 (statistical confluence)
   double                     strength;         // 0.0 to 1.0 (momentum/trend alignment)

   // Context
   SRegimeClassification     regime;
   STimeframeFeatures         primary_features;

   // Evidence & Conflicts
   string                     evidence[];
   string                     conflicts[];

   // Flags
   bool                       is_candidate;
   bool                       is_valid;

   // Explanatory formatting
   string                     formatted_explanation;

   void Reset()
   {
      symbol            = "";
      primary_timeframe = PERIOD_CURRENT;
      created_time      = 0;
      direction         = SIGNAL_DIR_NONE;
      quality           = SIGNAL_QUALITY_NONE;
      bias              = BIAS_NEUTRAL;
      status            = SIGNAL_STATUS_NONE;
      confidence        = 0.0;
      strength          = 0.0;
      is_candidate      = false;
      is_valid          = false;
      formatted_explanation = "NO_SIGNAL";
      regime.Reset();
      primary_features.Reset();
      ArrayResize(evidence, 0);
      ArrayResize(conflicts, 0);
   }

   void AddEvidence(const string reason)
   {
      int size = ArraySize(evidence);
      ArrayResize(evidence, size + 1);
      evidence[size] = reason;
   }

   void AddConflict(const string conflict)
   {
      int size = ArraySize(conflicts);
      ArrayResize(conflicts, size + 1);
      conflicts[size] = conflict;
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
      return "UNKNOWN";
   }

   string QualityToString() const
   {
      switch(quality)
      {
         case SIGNAL_QUALITY_STRONG_CANDIDATE: return "STRONG_CANDIDATE";
         case SIGNAL_QUALITY_CANDIDATE:        return "CANDIDATE";
         case SIGNAL_QUALITY_WEAK:             return "WEAK";
         case SIGNAL_QUALITY_NONE:             return "NONE";
      }
      return "NONE";
   }

   string BiasToString() const
   {
      switch(bias)
      {
         case BIAS_BULLISH:           return "BULLISH";
         case BIAS_BEARISH:           return "BEARISH";
         case BIAS_NEUTRAL:           return "NEUTRAL";
         case BIAS_INSUFFICIENT_DATA: return "INSUFFICIENT_DATA";
      }
      return "UNKNOWN";
   }

   string StatusToString() const
   {
      switch(status)
      {
         case SIGNAL_STATUS_CANDIDATE_ONLY: return "CANDIDATE_ONLY";
         case SIGNAL_STATUS_REJECTED:       return "REJECTED";
         case SIGNAL_STATUS_NONE:           return "NONE";
      }
      return "NONE";
   }
};

#endif
