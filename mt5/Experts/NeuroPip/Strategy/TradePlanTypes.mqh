//+------------------------------------------------------------------+
//| TradePlanTypes.mqh                                               |
//| ATG Trading Engine - Phase 5                                      |
//| Trade Plan Data Structures, Enums, and Gate Flags                |
//| MONITOR_ONLY - No execution capability                            |
//|                                                                  |
//| Converts approved Phase 4 Strategy Candidates into structured,   |
//| explainable Trade Plans without enabling live trading.            |
//+------------------------------------------------------------------+
#ifndef ATG_TRADE_PLAN_TYPES_MQH
#define ATG_TRADE_PLAN_TYPES_MQH

#include "StrategyTypes.mqh"
#include "../Execution/TradeTypes.mqh"
#include "../Execution/RiskEngine.mqh"
#include "../Execution/PositionSizer.mqh"

//+------------------------------------------------------------------+
//| Trade Plan Status Enums                                          |
//+------------------------------------------------------------------+
enum ENUM_TRADE_PLAN_STATUS
{
   TRADE_PLAN_PENDING = 0,          // Construction in progress / evaluating
   TRADE_PLAN_VALID,                // Plan fully constructed and all gates passed (DRY-RUN ONLY)
   TRADE_PLAN_REJECTED,             // Plan rejected by risk/sizing/broker/validation gates
   TRADE_PLAN_INSUFFICIENT_DATA,    // Insufficient market data or missing features
   TRADE_PLAN_EXPIRED,              // Plan exceeded validity window
   TRADE_PLAN_SUPERSEDED            // Newer plan replaced this one
};

// Aliases for compatibility
#define PLAN_IDLE          TRADE_PLAN_PENDING
#define PLAN_BUILDING      TRADE_PLAN_PENDING
#define PLAN_COMPLETE      TRADE_PLAN_VALID
#define PLAN_REJECTED      TRADE_PLAN_REJECTED
#define PLAN_EXPIRED       TRADE_PLAN_EXPIRED
#define PLAN_SUPERSEDED    TRADE_PLAN_SUPERSEDED

//+------------------------------------------------------------------+
//| Trade Plan Rejection Reason                                       |
//+------------------------------------------------------------------+
enum ENUM_PLAN_REJECTION_REASON
{
   PLAN_REJECT_NONE = 0,
   PLAN_REJECT_NO_STRATEGY,          // Gate 1: No approved strategy candidate
   PLAN_REJECT_DATA_INVALID,         // Gate 2: Missing or invalid market data / ATR
   PLAN_REJECT_DIRECTION_INVALID,    // Gate 3: Invalid or mismatched trade direction
   PLAN_REJECT_INVALID_ENTRY,        // Gate 4: Cannot compute valid entry price
   PLAN_REJECT_INVALID_STOP,         // Gate 5: Cannot compute valid stop loss (wrong side, zero dist)
   PLAN_REJECT_INVALID_TP,           // Gate 6: Cannot compute valid take profit level
   PLAN_REJECT_NEGATIVE_RR,          // Gate 7: Reward:Risk ratio is below configured minimum
   PLAN_REJECT_SPREAD_EXCEEDED,      // Gate 8: Current spread exceeds plan tolerance / invalidated
   PLAN_REJECT_BROKER_CONSTRAINTS,   // Gate 9: Broker stops/freeze/point constraints violated
   PLAN_REJECT_RISK_DENIED,          // Gate 10: RiskEngine rejected the request
   PLAN_REJECT_SIZING_FAILED,        // Gate 11: PositionSizer could not calculate volume
   PLAN_REJECT_ZERO_VOLUME,          // Gate 11b: Final volume is zero or below broker minimum
   PLAN_REJECT_MARGIN_INSUFFICIENT,  // Gate 11c: Insufficient margin for planned volume
   PLAN_REJECT_EXPIRED,              // Gate 12: Plan has expired
   PLAN_REJECT_DUPLICATE,            // Gate 13: Duplicate plan on same bar timestamp
   PLAN_REJECT_EXECUTION_DISABLED,   // Gate 14: Execution capability is disabled (expected dry-run)
   PLAN_REJECT_UNKNOWN
};

//+------------------------------------------------------------------+
//| 14 Validation Gate Bitmasks (Section 11)                         |
//+------------------------------------------------------------------+
#define PLAN_GATE_DECISION_VALID       0x0001
#define PLAN_GATE_DATA_VALID           0x0002
#define PLAN_GATE_DIRECTION_VALID      0x0004
#define PLAN_GATE_ENTRY_VALID          0x0008
#define PLAN_GATE_SL_VALID             0x0010
#define PLAN_GATE_TP_VALID             0x0020
#define PLAN_GATE_RR_VALID             0x0040
#define PLAN_GATE_SPREAD_VALID         0x0080
#define PLAN_GATE_BROKER_VALID         0x0100
#define PLAN_GATE_RISK_VALID           0x0200
#define PLAN_GATE_SIZING_VALID         0x0400
#define PLAN_GATE_EXPIRY_VALID         0x0800
#define PLAN_GATE_DUPLICATE_CHECK      0x1000
#define PLAN_GATE_SAFETY_CHECK         0x2000
#define PLAN_GATE_ALL_PASSED           0x3FFF

//+------------------------------------------------------------------+
//| Computed Stop Loss / Take Profit Levels                           |
//+------------------------------------------------------------------+
struct SPlanLevels
{
   double   entry_price;            // Planned entry price
   double   stop_loss;              // Planned stop loss price
   double   take_profit;            // Planned take profit price
   double   invalidation_price;     // Market structure invalidation level

   double   sl_distance_price;      // SL distance in price
   double   sl_distance_points;     // SL distance in points
   double   tp_distance_price;      // TP distance in price
   double   tp_distance_points;     // TP distance in points

   double   sl_atr_multiple;        // SL distance as ATR multiple
   double   tp_atr_multiple;        // TP distance as ATR multiple

   string   sl_method;              // How SL was computed (e.g., "ATR_2.0X", "SWING_LOW_5PT_BUFFER")
   string   tp_method;              // How TP was computed (e.g., "RR_2.0X", "SWING_HIGH")

   bool     levels_valid;

   void Reset()
   {
      entry_price          = 0.0;
      stop_loss            = 0.0;
      take_profit          = 0.0;
      invalidation_price   = 0.0;
      sl_distance_price    = 0.0;
      sl_distance_points   = 0.0;
      tp_distance_price    = 0.0;
      tp_distance_points   = 0.0;
      sl_atr_multiple      = 0.0;
      tp_atr_multiple      = 0.0;
      sl_method            = "";
      tp_method            = "";
      levels_valid         = false;
   }
};

//+------------------------------------------------------------------+
//| Risk Integration Result (wraps existing RiskEngine output)        |
//+------------------------------------------------------------------+
struct SPlanRiskResult
{
   bool     approved;
   double   equity;
   double   risk_percent;
   double   risk_money;
   string   rejection_detail;

   void Reset()
   {
      approved         = false;
      equity           = 0.0;
      risk_percent     = 0.0;
      risk_money       = 0.0;
      rejection_detail = "";
   }
};

//+------------------------------------------------------------------+
//| Position Sizing Result (wraps existing PositionSizer output)      |
//+------------------------------------------------------------------+
struct SPlanSizingResult
{
   double   raw_volume;
   double   final_volume;
   double   volume_min;
   double   volume_max;
   double   volume_step;
   double   estimated_loss;
   double   estimated_reward;
   string   rejection_detail;

   void Reset()
   {
      raw_volume       = 0.0;
      final_volume     = 0.0;
      volume_min       = 0.0;
      volume_max       = 0.0;
      volume_step      = 0.0;
      estimated_loss   = 0.0;
      estimated_reward = 0.0;
      rejection_detail = "";
   }
};

//+------------------------------------------------------------------+
//| Complete Trade Plan Record                                        |
//| Deterministic, explainable, fully structured trade plan.          |
//| Meets all Section 1 Contract specifications.                      |
//| This is a PLAN ONLY — it does NOT execute.                        |
//+------------------------------------------------------------------+
struct STradePlan
{
   // Identity
   ulong                          plan_id;
   string                         symbol;
   string                         strategy_id;
   string                         strategy_version;
   ulong                          source_decision_id;       // Links back to Phase 4 decision
   ulong                          strategy_decision_id;     // Alias for source_decision_id

   // Direction
   ENUM_ATG_TRADE_DIRECTION       direction;

   // Timeframes & Timestamps
   ENUM_TIMEFRAMES                primary_timeframe;
   datetime                       creation_time;
   datetime                       created_time;             // Alias
   datetime                       source_bar_time;
   datetime                       expiration_time;
   datetime                       expiry_time;              // Alias

   // Plan status & explainability
   ENUM_TRADE_PLAN_STATUS         plan_status;
   ENUM_TRADE_PLAN_STATUS         status;                   // Alias
   ENUM_PLAN_REJECTION_REASON     rejection_reason;
   string                         rejection_detail;
   uint                           validation_flags;

   // Computed price levels
   double                         entry_price;
   double                         stop_loss;
   double                         take_profit;
   double                         invalidation_price;

   // Distances
   double                         risk_distance_price;
   double                         risk_distance_points;
   double                         reward_distance_price;
   double                         reward_distance_points;
   double                         risk_reward_ratio;
   double                         reward_risk_ratio;        // Alias
   double                         min_reward_risk;

   // Risk economics
   double                         account_equity;
   double                         risk_percent;
   double                         risk_money;

   // Position sizing
   double                         calculated_volume;
   double                         normalized_volume;
   double                         volume_min;
   double                         volume_max;
   double                         volume_step;

   // Broker parameters
   double                         point_size;
   double                         tick_size;
   double                         tick_value;
   int                            spread_at_planning;
   int                            stops_level;
   int                            freeze_level;

   // Financial expectations
   double                         expected_loss;
   double                         expected_reward;

   // Strategy context & confluence
   ENUM_ATG_MARKET_REGIME         regime;
   double                         strategy_confidence;
   double                         strategy_quality;
   string                         supporting_evidence;

   // Sub-structs for structured access
   SPlanLevels                    levels;
   SPlanRiskResult                risk;
   SPlanSizingResult              sizing;

   // Safety boundaries (HARD LOCKS)
   bool                           candidate_only;           // Always true
   bool                           execution_disabled;       // Always true
   bool                           execution_authorized;     // ALWAYS false

   // Human-readable formatted summary
   string                         formatted_plan;

   //+--------------------------------------------------------------+
   //| Reset                                                         |
   //+--------------------------------------------------------------+
   void Reset()
   {
      plan_id                = 0;
      symbol                 = "";
      strategy_id            = "";
      strategy_version       = "";
      source_decision_id     = 0;
      strategy_decision_id   = 0;

      direction              = ATG_DIRECTION_NONE;
      primary_timeframe      = PERIOD_M15;
      creation_time          = 0;
      created_time           = 0;
      source_bar_time        = 0;
      expiration_time        = 0;
      expiry_time            = 0;

      plan_status            = TRADE_PLAN_PENDING;
      status                 = TRADE_PLAN_PENDING;
      rejection_reason       = PLAN_REJECT_NONE;
      rejection_detail       = "";
      validation_flags       = 0;

      entry_price            = 0.0;
      stop_loss              = 0.0;
      take_profit            = 0.0;
      invalidation_price     = 0.0;

      risk_distance_price    = 0.0;
      risk_distance_points   = 0.0;
      reward_distance_price  = 0.0;
      reward_distance_points = 0.0;
      risk_reward_ratio      = 0.0;
      reward_risk_ratio      = 0.0;
      min_reward_risk        = 1.5;

      account_equity         = 0.0;
      risk_percent           = 0.0;
      risk_money             = 0.0;

      calculated_volume      = 0.0;
      normalized_volume      = 0.0;
      volume_min             = 0.0;
      volume_max             = 0.0;
      volume_step            = 0.0;

      point_size             = 0.0;
      tick_size              = 0.0;
      tick_value             = 0.0;
      spread_at_planning     = 0;
      stops_level            = 0;
      freeze_level           = 0;

      expected_loss          = 0.0;
      expected_reward        = 0.0;

      regime                 = REGIME_INSUFFICIENT_DATA;
      strategy_confidence    = 0.0;
      strategy_quality       = 0.0;
      supporting_evidence    = "";

      levels.Reset();
      risk.Reset();
      sizing.Reset();

      candidate_only         = true;
      execution_disabled     = true;
      execution_authorized   = false;  // HARD LOCK — never true

      formatted_plan         = "TRADE_PLAN_PENDING: No trade plan generated";
   }

   //+--------------------------------------------------------------+
   //| Status conversion                                             |
   //+--------------------------------------------------------------+
   string StatusToString() const
   {
      switch(plan_status)
      {
         case TRADE_PLAN_PENDING:           return "TRADE_PLAN_PENDING";
         case TRADE_PLAN_VALID:             return "TRADE_PLAN_VALID";
         case TRADE_PLAN_REJECTED:          return "TRADE_PLAN_REJECTED";
         case TRADE_PLAN_INSUFFICIENT_DATA: return "TRADE_PLAN_INSUFFICIENT_DATA";
         case TRADE_PLAN_EXPIRED:           return "TRADE_PLAN_EXPIRED";
         case TRADE_PLAN_SUPERSEDED:        return "TRADE_PLAN_SUPERSEDED";
      }
      return "UNKNOWN";
   }

   //+--------------------------------------------------------------+
   //| Rejection conversion                                          |
   //+--------------------------------------------------------------+
   string RejectionToString() const
   {
      switch(rejection_reason)
      {
         case PLAN_REJECT_NONE:                  return "NONE";
         case PLAN_REJECT_NO_STRATEGY:           return "NO_STRATEGY";
         case PLAN_REJECT_DATA_INVALID:          return "DATA_INVALID";
         case PLAN_REJECT_DIRECTION_INVALID:     return "DIRECTION_INVALID";
         case PLAN_REJECT_INVALID_ENTRY:         return "INVALID_ENTRY";
         case PLAN_REJECT_INVALID_STOP:          return "INVALID_STOP";
         case PLAN_REJECT_INVALID_TP:            return "INVALID_TP";
         case PLAN_REJECT_NEGATIVE_RR:           return "NEGATIVE_RR";
         case PLAN_REJECT_SPREAD_EXCEEDED:       return "SPREAD_EXCEEDED";
         case PLAN_REJECT_BROKER_CONSTRAINTS:    return "BROKER_CONSTRAINTS_VIOLATED";
         case PLAN_REJECT_RISK_DENIED:           return "RISK_DENIED";
         case PLAN_REJECT_SIZING_FAILED:         return "SIZING_FAILED";
         case PLAN_REJECT_ZERO_VOLUME:           return "ZERO_VOLUME";
         case PLAN_REJECT_MARGIN_INSUFFICIENT:   return "MARGIN_INSUFFICIENT";
         case PLAN_REJECT_EXPIRED:               return "EXPIRED";
         case PLAN_REJECT_DUPLICATE:             return "DUPLICATE";
         case PLAN_REJECT_EXECUTION_DISABLED:    return "EXECUTION_DISABLED";
         case PLAN_REJECT_UNKNOWN:               return "UNKNOWN";
      }
      return "UNKNOWN";
   }

   //+--------------------------------------------------------------+
   //| Direction conversion                                          |
   //+--------------------------------------------------------------+
   string DirectionToString() const
   {
      switch(direction)
      {
         case ATG_DIRECTION_BUY:  return "BUY";
         case ATG_DIRECTION_SELL: return "SELL";
         case ATG_DIRECTION_NONE: return "NONE";
      }
      return "NONE";
   }
};

#endif
