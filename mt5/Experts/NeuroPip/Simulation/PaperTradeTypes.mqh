//+------------------------------------------------------------------+
//| PaperTradeTypes.mqh                                              |
//| NeuroPip - Phase 6                                      |
//| Paper Trading Data Structures, Enums & Lifecycle Contracts       |
//| MONITOR_ONLY - No execution capability                            |
//|                                                                  |
//| Dedicated paper trading / simulation contract without live orders|
//+------------------------------------------------------------------+
#ifndef ATG_PAPER_TRADE_TYPES_MQH
#define ATG_PAPER_TRADE_TYPES_MQH

#include "../Strategy/StrategyTypes.mqh"
#include "../Strategy/TradePlanTypes.mqh"
#include "../Execution/TradeTypes.mqh"
#include "../Analytics/ForwardEvidenceTypes.mqh"

//+------------------------------------------------------------------+
//| Paper Trade Status Enums                                         |
//+------------------------------------------------------------------+
enum ENUM_PAPER_TRADE_STATUS
{
   PAPER_PENDING = 0,               // Trade plan received, waiting to simulate entry
   PAPER_OPEN,                      // Simulated position is actively open and monitored
   PAPER_CLOSED_TP,                 // Simulated position hit Take Profit
   PAPER_CLOSED_SL,                 // Simulated position hit Stop Loss
   PAPER_CLOSED_EXPIRY,             // Simulated position closed due to holding duration expiry
   PAPER_CLOSED_INVALIDATION,       // Simulated position closed due to structural invalidation
   PAPER_CANCELLED,                 // Trade cancelled before entry
   PAPER_REJECTED                   // Trade plan rejected or invalid for simulation
};

//+------------------------------------------------------------------+
//| Paper Trade Exit Reason Codes                                    |
//+------------------------------------------------------------------+
#define EXIT_REASON_TP                          "TP_HIT"
#define EXIT_REASON_SL                          "SL_HIT"
#define EXIT_REASON_EXPIRY                      "HOLDING_EXPIRED"
#define EXIT_REASON_INVALIDATION                "STRUCTURAL_INVALIDATION"
#define EXIT_REASON_SAME_BAR_CONSERVATIVE_SL    "SAME_BAR_AMBIGUITY_CONSERVATIVE_SL"
#define EXIT_REASON_MANUAL                      "MANUAL_CLOSE"

//+------------------------------------------------------------------+
//| Complete Paper Trade Record                                      |
//| Fully structured, deterministic simulated trade representation.  |
//| This record represents a SIMULATED trade — NOT a live order.     |
//+------------------------------------------------------------------+
struct SPaperTrade
{
   // Identification
   ulong                          paper_trade_id;        // Unique simulation trade identifier
   ulong                          source_plan_id;        // Source Phase 5 Trade Plan ID
   string                         strategy_id;           // Strategy identifier (e.g. "NEUROPIP_TREND_CONTINUATION")
   string                         symbol;                // Broker symbol (e.g. "EURUSDm")
   ENUM_ATG_TRADE_DIRECTION       direction;             // Trade direction (BUY / SELL)
   ENUM_TIMEFRAMES                primary_timeframe;     // Primary analysis timeframe (e.g. PERIOD_M15)

   // Timestamps
   datetime                       entry_time;            // Simulated entry timestamp
   datetime                       exit_time;             // Simulated exit timestamp
   datetime                       source_bar_time;       // Closed bar time of setup creation
   int                            holding_duration_sec;  // Elapsed holding duration in seconds

   // Price Levels
   double                         entry_price;           // Simulated entry price (exact Phase 5 planned entry)
   double                         stop_loss;             // Initial protective stop loss
   double                         take_profit;           // Initial target take profit
   double                         exit_price;            // Realized simulated exit price

   // Excursions (MAE / MFE)
   double                         mae_points;            // Maximum Adverse Excursion in points
   double                         mfe_points;            // Maximum Favorable Excursion in points

   // Sizing & Risk Parameters
   double                         volume;                // Position size (exact Phase 5 normalized volume)
   double                         risk_money;            // Planned risk budget in cash
   double                         equity_at_entry;       // Simulated paper equity at entry time
   double                         risk_percent;          // Configured risk percent
   double                         planned_rr;            // Planned Reward:Risk ratio

   // Financial Results
   double                         gross_pnl;             // Gross profit/loss in deposit currency
   double                         simulated_costs;       // Simulated spread/commission/swap costs
   double                         net_pnl;               // Net profit/loss in deposit currency
   double                         realized_r;            // Realized R multiple (Net PnL / Risk Money)

   // Lifecycle & State
   ENUM_PAPER_TRADE_STATUS        status;                // Current paper trade state
   string                         exit_reason;           // Explicit reason for closure

   // Strategy Context at Entry
   double                         strategy_confidence;   // Phase 4 confidence score
   double                         strategy_quality;      // Phase 4 quality score
   ENUM_ATG_MARKET_REGIME         regime;                // Regime at trade creation
   string                         explanation;           // Confluence explanation

   // Safety Lock
   bool                           candidate_only;        // Permanently true (HARD SAFETY LOCK)

   // Phase 9 Forward Evidence & Classification
   ENUM_DATASET_CLASS             dataset_class;          // FORWARD_LIVE_PAPER vs SYNTHETIC_TEST
   ENUM_DATA_QUALITY_FLAG         data_quality;           // VALID, WARNING, INVALID
   string                         quality_warning_reason; // Explanation of warning or invalidity
   string                         config_fingerprint;     // Frozen config fingerprint at entry
   string                         cohort_id;              // Evidence cohort ID
   int                            entry_spread_points;    // Spread at entry time in points

   // Formatted Audit Text
   string                         formatted_trade;

   //+--------------------------------------------------------------+
   //| Reset                                                        |
   //+--------------------------------------------------------------+
   void Reset()
   {
      paper_trade_id       = 0;
      source_plan_id       = 0;
      strategy_id          = "";
      symbol               = "";
      direction            = ATG_DIRECTION_NONE;
      primary_timeframe    = PERIOD_M15;

      entry_time           = 0;
      exit_time            = 0;
      source_bar_time      = 0;
      holding_duration_sec = 0;

      entry_price          = 0.0;
      stop_loss            = 0.0;
      take_profit          = 0.0;
      exit_price           = 0.0;

      mae_points           = 0.0;
      mfe_points           = 0.0;

      volume               = 0.0;
      risk_money           = 0.0;
      equity_at_entry      = 0.0;
      risk_percent         = 0.0;
      planned_rr           = 0.0;

      gross_pnl            = 0.0;
      simulated_costs      = 0.0;
      net_pnl              = 0.0;
      realized_r           = 0.0;

      status               = PAPER_PENDING;
      exit_reason          = "";

      strategy_confidence  = 0.0;
      strategy_quality     = 0.0;
      regime               = REGIME_INSUFFICIENT_DATA;
      explanation          = "";

      candidate_only       = true;  // HARD SAFETY LOCK

      dataset_class          = DATASET_FORWARD_LIVE_PAPER;
      data_quality           = DATA_QUALITY_VALID;
      quality_warning_reason = "NONE";
      config_fingerprint     = "";
      cohort_id              = "";
      entry_spread_points    = 0;

      formatted_trade      = "PAPER_PENDING: No simulated trade executed";
   }

   //+--------------------------------------------------------------+
   //| Status conversion                                            |
   //+--------------------------------------------------------------+
   string StatusToString() const
   {
      switch(status)
      {
         case PAPER_PENDING:              return "PAPER_PENDING";
         case PAPER_OPEN:                 return "PAPER_OPEN";
         case PAPER_CLOSED_TP:            return "PAPER_CLOSED_TP";
         case PAPER_CLOSED_SL:            return "PAPER_CLOSED_SL";
         case PAPER_CLOSED_EXPIRY:        return "PAPER_CLOSED_EXPIRY";
         case PAPER_CLOSED_INVALIDATION:  return "PAPER_CLOSED_INVALIDATION";
         case PAPER_CANCELLED:            return "PAPER_CANCELLED";
         case PAPER_REJECTED:             return "PAPER_REJECTED";
      }
      return "UNKNOWN";
   }

   //+--------------------------------------------------------------+
   //| Direction conversion                                         |
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

   //+--------------------------------------------------------------+
   //| CSV Serialization (Phase 7 Persistence)                       |
   //+--------------------------------------------------------------+
   string ToCsv() const
   {
      string clean_strat   = strategy_id;
      string clean_reason  = exit_reason;
      string clean_quality = quality_warning_reason;
      StringReplace(clean_strat, ",", ";");
      StringReplace(clean_reason, ",", ";");
      StringReplace(clean_quality, ",", ";");
      StringReplace(clean_strat, "\n", " ");
      StringReplace(clean_reason, "\n", " ");
      StringReplace(clean_quality, "\n", " ");
      StringReplace(clean_strat, "\r", " ");
      StringReplace(clean_reason, "\r", " ");
      StringReplace(clean_quality, "\r", " ");

      return StringFormat(
         "%I64u,%I64u,%s,%s,%d,%d,%I64d,%I64d,%I64d,%d,%.5f,%.5f,%.5f,%.5f,%.1f,%.1f,%.4f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%s,%.2f,%.2f,%d,%d,%d,%d,%s,%s,%s,%d",
         paper_trade_id,
         source_plan_id,
         clean_strat,
         symbol,
         (int)direction,
         (int)primary_timeframe,
         (long)entry_time,
         (long)exit_time,
         (long)source_bar_time,
         holding_duration_sec,
         entry_price,
         stop_loss,
         take_profit,
         exit_price,
         mae_points,
         mfe_points,
         volume,
         risk_money,
         equity_at_entry,
         risk_percent,
         planned_rr,
         gross_pnl,
         simulated_costs,
         net_pnl,
         realized_r,
         (int)status,
         clean_reason,
         strategy_confidence,
         strategy_quality,
         (int)regime,
         candidate_only ? 1 : 0,
         (int)dataset_class,
         (int)data_quality,
         clean_quality,
         config_fingerprint,
         cohort_id,
         entry_spread_points
      );
   }

   //+--------------------------------------------------------------+
   //| CSV Deserialization with strict integrity checks             |
   //+--------------------------------------------------------------+
   bool FromCsv(const string line)
   {
      string tokens[];
      int count = StringSplit(line, ',', tokens);
      if(count != 31 && count != 37) return false;

      paper_trade_id       = (ulong)StringToInteger(tokens[0]);
      source_plan_id       = (ulong)StringToInteger(tokens[1]);
      strategy_id          = tokens[2];
      symbol               = tokens[3];
      direction            = (ENUM_ATG_TRADE_DIRECTION)StringToInteger(tokens[4]);
      primary_timeframe    = (ENUM_TIMEFRAMES)StringToInteger(tokens[5]);
      entry_time           = (datetime)StringToInteger(tokens[6]);
      exit_time            = (datetime)StringToInteger(tokens[7]);
      source_bar_time      = (datetime)StringToInteger(tokens[8]);
      holding_duration_sec = (int)StringToInteger(tokens[9]);

      entry_price          = StringToDouble(tokens[10]);
      stop_loss            = StringToDouble(tokens[11]);
      take_profit          = StringToDouble(tokens[12]);
      exit_price           = StringToDouble(tokens[13]);
      mae_points           = StringToDouble(tokens[14]);
      mfe_points           = StringToDouble(tokens[15]);

      volume               = StringToDouble(tokens[16]);
      risk_money           = StringToDouble(tokens[17]);
      equity_at_entry      = StringToDouble(tokens[18]);
      risk_percent         = StringToDouble(tokens[19]);
      planned_rr           = StringToDouble(tokens[20]);

      gross_pnl            = StringToDouble(tokens[21]);
      simulated_costs      = StringToDouble(tokens[22]);
      net_pnl              = StringToDouble(tokens[23]);
      realized_r           = StringToDouble(tokens[24]);

      status               = (ENUM_PAPER_TRADE_STATUS)StringToInteger(tokens[25]);
      exit_reason          = tokens[26];
      strategy_confidence  = StringToDouble(tokens[27]);
      strategy_quality     = StringToDouble(tokens[28]);
      regime               = (ENUM_ATG_MARKET_REGIME)StringToInteger(tokens[29]);
      candidate_only       = (StringToInteger(tokens[30]) != 0);

      if(count >= 37)
      {
         dataset_class          = (ENUM_DATASET_CLASS)StringToInteger(tokens[31]);
         data_quality           = (ENUM_DATA_QUALITY_FLAG)StringToInteger(tokens[32]);
         quality_warning_reason = tokens[33];
         config_fingerprint     = tokens[34];
         cohort_id              = tokens[35];
         entry_spread_points    = (int)StringToInteger(tokens[36]);
      }
      else
      {
         dataset_class          = DATASET_FORWARD_LIVE_PAPER;
         data_quality           = DATA_QUALITY_VALID;
         quality_warning_reason = "NONE";
         config_fingerprint     = "FP-LEGACY";
         cohort_id              = "COHORT_01";
         entry_spread_points    = 0;
      }

      // Data Integrity & Safety validations
      if(paper_trade_id == 0 || symbol == "")
         return false;
      if(entry_price <= 0.0 || stop_loss <= 0.0 || take_profit <= 0.0 || volume <= 0.0)
         return false;
      if(entry_time <= 0)
         return false;
      if(!candidate_only)
         return false; // Absolute safety lock: must be a simulated candidate

      return true;
   }
};

#endif
