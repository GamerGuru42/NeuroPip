//+------------------------------------------------------------------+
//| TradeTypes.mqh                                                   |
//| NeuroPip - Phase 2A                                   |
//| Execution Contracts                                              |
//|                                                                  |
//| Defines trade intent/result structures only.                    |
//| No trading operations are performed here.                       |
//+------------------------------------------------------------------+
#ifndef ATG_TRADE_TYPES_MQH
#define ATG_TRADE_TYPES_MQH

//+------------------------------------------------------------------+
//| Trade direction                                                  |
//+------------------------------------------------------------------+
enum ENUM_ATG_TRADE_DIRECTION
{
   ATG_DIRECTION_NONE = 0,
   ATG_DIRECTION_BUY,
   ATG_DIRECTION_SELL
};

//+------------------------------------------------------------------+
//| Execution request state                                          |
//+------------------------------------------------------------------+
enum ENUM_ATG_EXECUTION_STATE
{
   ATG_EXECUTION_IDLE = 0,
   ATG_EXECUTION_PENDING,
   ATG_EXECUTION_VALIDATING,
   ATG_EXECUTION_REJECTED,
   ATG_EXECUTION_CHECKED,
   ATG_EXECUTION_SUBMITTED,
   ATG_EXECUTION_CONFIRMED,
   ATG_EXECUTION_FAILED
};

//+------------------------------------------------------------------+
//| Rejection reason                                                 |
//+------------------------------------------------------------------+
enum ENUM_ATG_REJECTION_REASON
{
   ATG_REJECT_NONE = 0,
   ATG_REJECT_EXECUTION_DISABLED,
   ATG_REJECT_INVALID_SYMBOL,
   ATG_REJECT_INVALID_DIRECTION,
   ATG_REJECT_INVALID_VOLUME,
   ATG_REJECT_INVALID_PRICE,
   ATG_REJECT_INVALID_STOPS,
   ATG_REJECT_SPREAD,
   ATG_REJECT_RISK,
   ATG_REJECT_MARGIN,
   ATG_REJECT_DUPLICATE,
   ATG_REJECT_SAFE_STATE,
   ATG_REJECT_RUNTIME,
   ATG_REJECT_ORDER_CHECK,
   ATG_REJECT_BROKER,
   ATG_REJECT_UNKNOWN
};

//+------------------------------------------------------------------+
//| Trade intent                                                     |
//+------------------------------------------------------------------+
struct SATGTradeIntent
{
   // Identity
   ulong request_id;
   datetime created_time;

   // Instrument
   string symbol;

   // Direction
   ENUM_ATG_TRADE_DIRECTION direction;

   // Requested execution parameters
   double volume;
   double requested_price;

   // Protection
   double stop_loss;
   double take_profit;

   // Risk metadata
   double risk_percent;
   double risk_amount;
   double expected_reward_risk;

   // Signal metadata
   double signal_confidence;
   string signal_source;
   string strategy_id;
   string comment;

   // Execution constraints
   int max_spread_points;
   int deviation_points;
   double sl_distance_pts;

   // State
   ENUM_ATG_EXECUTION_STATE state;
   ENUM_ATG_REJECTION_REASON rejection_reason;
   string reject_detail;

   // Validation flags
   bool risk_approved;
   bool symbol_validated;
   bool volume_validated;
   bool price_validated;
   bool stops_validated;
   bool spread_validated;
   bool margin_validated;
   bool order_checked;

   //+--------------------------------------------------------------+
   //| Constructor                                                   |
   //+--------------------------------------------------------------+
   SATGTradeIntent()
   {
      request_id = 0;
      created_time = 0;

      symbol = "";

      direction =
         ATG_DIRECTION_NONE;

      volume = 0.0;
      requested_price = 0.0;

      stop_loss = 0.0;
      take_profit = 0.0;

      risk_percent = 0.0;
      risk_amount = 0.0;
      expected_reward_risk = 0.0;

      signal_confidence = 0.0;
      signal_source = "";
      strategy_id = "";

      max_spread_points = 0;
      deviation_points = 0;
      sl_distance_pts = 0.0;
      comment = "";
      reject_detail = "";

      state =
         ATG_EXECUTION_IDLE;

      rejection_reason =
         ATG_REJECT_NONE;

      risk_approved = false;
      symbol_validated = false;
      volume_validated = false;
      price_validated = false;
      stops_validated = false;
      spread_validated = false;
      margin_validated = false;
      order_checked = false;
   }
};

//+------------------------------------------------------------------+
//| Execution result                                                 |
//+------------------------------------------------------------------+
struct SATGExecutionResult
{
   ulong request_id;

   bool accepted;
   bool submitted;
   bool confirmed;

   uint retcode;

   string broker_comment;

   ulong order_ticket;
   ulong deal_ticket;
   ulong position_ticket;

   double executed_volume;
   double executed_price;

   ENUM_ATG_EXECUTION_STATE state;
   ENUM_ATG_REJECTION_REASON rejection_reason;

   datetime result_time;

   SATGExecutionResult()
   {
      request_id = 0;

      accepted = false;
      submitted = false;
      confirmed = false;

      retcode = 0;

      broker_comment = "";

      order_ticket = 0;
      deal_ticket = 0;
      position_ticket = 0;

      executed_volume = 0.0;
      executed_price = 0.0;

      state =
         ATG_EXECUTION_IDLE;

      rejection_reason =
         ATG_REJECT_NONE;

      result_time = 0;
   }
};

//+------------------------------------------------------------------+
//| Phase 2F Compatibility Aliases                                   |
//+------------------------------------------------------------------+
#define entry_price requested_price
#define sl_price stop_loss
#define tp_price take_profit
#define strategy_name strategy_id
#define reject_reason rejection_reason
#define ATG_REJECT_REQUEST_BUILD_FAILED ATG_REJECT_BROKER
#define ATG_STATE_REJECTED ATG_EXECUTION_REJECTED
#define ATG_STATE_RECONCILED ATG_EXECUTION_CHECKED
#define ATG_STATE_REQUEST_BUILT ATG_EXECUTION_CHECKED
#define ATG_STATE_ORDER_CHECKED ATG_EXECUTION_CHECKED
#define ATG_STATE_RISK_VALIDATED ATG_EXECUTION_PENDING
#define ATG_STATE_EXECUTION_VALIDATED ATG_EXECUTION_VALIDATING
#define ATG_STATE_CREATED ATG_EXECUTION_IDLE
#define ATG_STATE_APPROVED ATG_EXECUTION_SUBMITTED
#define ATG_STATE_ERROR ATG_EXECUTION_FAILED
#define ENUM_ATG_DIRECTION ENUM_ATG_TRADE_DIRECTION
#define ENUM_ATG_EXEC_STATE ENUM_ATG_EXECUTION_STATE
#define ENUM_ATG_REJECT_REASON ENUM_ATG_REJECTION_REASON
#define ENUM_ATG_INTENT_SOURCE string
#define ATG_SOURCE_SYSTEM_TEST "SYSTEM_TEST"
#define ATG_SOURCE_MANUAL_TEST "MANUAL_TEST"
#define ATG_SOURCE_STRATEGY "STRATEGY"
#define source signal_source

#endif

//+------------------------------------------------------------------+