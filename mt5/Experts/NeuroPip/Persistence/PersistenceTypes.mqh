//+------------------------------------------------------------------+
//| PersistenceTypes.mqh                                             |
//| NeuroPip - Phase 7                                      |
//| Persistent Storage, Audit Trail & Historical Analytics Contracts |
//| MONITOR_ONLY - No execution capability                            |
//+------------------------------------------------------------------+
#ifndef ATG_PERSISTENCE_TYPES_MQH
#define ATG_PERSISTENCE_TYPES_MQH

#include "../Simulation/PaperTradeTypes.mqh"

// Current schema version for paper trading persistence (Phase 9 Forward Evidence)
#define ATG_STORAGE_SCHEMA_VERSION  2

//+------------------------------------------------------------------+
//| Audit Event Types                                                |
//+------------------------------------------------------------------+
enum ENUM_AUDIT_EVENT_TYPE
{
   AUDIT_PAPER_TRADE_CREATED = 0,
   AUDIT_PAPER_TRADE_OPENED,
   AUDIT_PAPER_TRADE_CLOSED,
   AUDIT_PAPER_TRADE_TP,
   AUDIT_PAPER_TRADE_SL,
   AUDIT_PAPER_TRADE_EXPIRED,
   AUDIT_SAME_BAR_AMBIGUITY,
   AUDIT_PERSISTENCE_LOAD,
   AUDIT_PERSISTENCE_SAVE,
   AUDIT_PERSISTENCE_ERROR,
   AUDIT_PERFORMANCE_UPDATE,
   AUDIT_RECOVERY_SUCCESS,
   AUDIT_RECOVERY_REJECTED,
   AUDIT_COHORT_INITIALIZED,
   AUDIT_COHORT_MILESTONE,
   AUDIT_CONFIG_FINGERPRINT_VERIFIED,
   AUDIT_CONFIG_TAMPERING_DETECTED,
   AUDIT_FORWARD_SNAPSHOT_SAVED,
   AUDIT_DATA_QUALITY_WARNING,
   AUDIT_DATA_QUALITY_INVALID,
   AUDIT_ALERT_TRIGGERED
};

//+------------------------------------------------------------------+
//| Convert Audit Event Type to String                               |
//+------------------------------------------------------------------+
inline string AuditEventToString(ENUM_AUDIT_EVENT_TYPE evt)
{
   switch(evt)
   {
      case AUDIT_PAPER_TRADE_CREATED:         return "PAPER_TRADE_CREATED";
      case AUDIT_PAPER_TRADE_OPENED:          return "PAPER_TRADE_OPENED";
      case AUDIT_PAPER_TRADE_CLOSED:          return "PAPER_TRADE_CLOSED";
      case AUDIT_PAPER_TRADE_TP:              return "PAPER_TRADE_TP";
      case AUDIT_PAPER_TRADE_SL:              return "PAPER_TRADE_SL";
      case AUDIT_PAPER_TRADE_EXPIRED:         return "PAPER_TRADE_EXPIRED";
      case AUDIT_SAME_BAR_AMBIGUITY:          return "SAME_BAR_AMBIGUITY";
      case AUDIT_PERSISTENCE_LOAD:            return "PERSISTENCE_LOAD";
      case AUDIT_PERSISTENCE_SAVE:            return "PERSISTENCE_SAVE";
      case AUDIT_PERSISTENCE_ERROR:           return "PERSISTENCE_ERROR";
      case AUDIT_PERFORMANCE_UPDATE:          return "PERFORMANCE_UPDATE";
      case AUDIT_RECOVERY_SUCCESS:            return "RECOVERY_SUCCESS";
      case AUDIT_RECOVERY_REJECTED:           return "RECOVERY_REJECTED";
      case AUDIT_COHORT_INITIALIZED:          return "COHORT_INITIALIZED";
      case AUDIT_COHORT_MILESTONE:            return "COHORT_MILESTONE";
      case AUDIT_CONFIG_FINGERPRINT_VERIFIED: return "CONFIG_FINGERPRINT_VERIFIED";
      case AUDIT_CONFIG_TAMPERING_DETECTED:   return "CONFIG_TAMPERING_DETECTED";
      case AUDIT_FORWARD_SNAPSHOT_SAVED:      return "FORWARD_SNAPSHOT_SAVED";
      case AUDIT_DATA_QUALITY_WARNING:        return "DATA_QUALITY_WARNING";
      case AUDIT_DATA_QUALITY_INVALID:        return "DATA_QUALITY_INVALID";
      case AUDIT_ALERT_TRIGGERED:             return "ALERT_TRIGGERED";
   }
   return "UNKNOWN_EVENT";
}

//+------------------------------------------------------------------+
//| Storage Status                                                   |
//+------------------------------------------------------------------+
enum ENUM_STORAGE_STATUS
{
   STORAGE_STATUS_UNINITIALIZED = 0,
   STORAGE_STATUS_READY,
   STORAGE_STATUS_READ_ONLY,
   STORAGE_STATUS_CORRUPTED,
   STORAGE_STATUS_DISABLED
};

//+------------------------------------------------------------------+
//| Recovery Status                                                  |
//+------------------------------------------------------------------+
enum ENUM_RECOVERY_STATUS
{
   RECOVERY_STATUS_NONE = 0,
   RECOVERY_STATUS_SUCCESS,
   RECOVERY_STATUS_PARTIAL,
   RECOVERY_STATUS_REJECTED,
   RECOVERY_STATUS_CORRUPTED
};

//+------------------------------------------------------------------+
//| Structured Equity History Point                                  |
//+------------------------------------------------------------------+
struct SEquityPoint
{
   datetime timestamp;
   string   event_type;     // e.g. "START", "TRADE_OPEN", "TRADE_CLOSE", "RECOVERY"
   ulong    trade_id;       // Associated trade ID (0 if start/periodic)
   double   equity;         // Current simulated paper equity
   double   balance;        // Closed trade paper balance
   double   peak_equity;    // High watermark
   double   drawdown;       // Peak - Current
   double   drawdown_pct;   // (Peak - Current) / Peak * 100
   double   realized_pnl;   // Net P&L of event
   double   realized_r;     // Realized R of event

   void Reset()
   {
      timestamp    = 0;
      event_type   = "INIT";
      trade_id     = 0;
      equity       = 0.0;
      balance      = 0.0;
      peak_equity  = 0.0;
      drawdown     = 0.0;
      drawdown_pct = 0.0;
      realized_pnl = 0.0;
      realized_r   = 0.0;
   }

   string ToCsv() const
   {
      return StringFormat("%I64d,%s,%I64u,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f",
         (long)timestamp,
         event_type,
         trade_id,
         equity,
         balance,
         peak_equity,
         drawdown,
         drawdown_pct,
         realized_pnl,
         realized_r
      );
   }

   bool FromCsv(const string line)
   {
      string tokens[];
      int count = StringSplit(line, ',', tokens);
      if(count < 10) return false;

      timestamp    = (datetime)StringToInteger(tokens[0]);
      event_type   = tokens[1];
      trade_id     = (ulong)StringToInteger(tokens[2]);
      equity       = StringToDouble(tokens[3]);
      balance      = StringToDouble(tokens[4]);
      peak_equity  = StringToDouble(tokens[5]);
      drawdown     = StringToDouble(tokens[6]);
      drawdown_pct = StringToDouble(tokens[7]);
      realized_pnl = StringToDouble(tokens[8]);
      realized_r   = StringToDouble(tokens[9]);

      // Integrity checks
      if(timestamp <= 0 || equity < 0.0 || peak_equity < 0.0)
         return false;

      return true;
   }
};

//+------------------------------------------------------------------+
//| Time Period Aggregation Result (Daily / Weekly / Monthly)        |
//+------------------------------------------------------------------+
struct STimePeriodPerformance
{
   string   period_type;   // "DAILY", "WEEKLY", "MONTHLY"
   string   period_key;    // e.g. "2026-10-04", "2026-W40", "2026-10"
   datetime start_time;    // Window start
   datetime end_time;      // Window end
   int      trades;        // Total completed trades in period
   int      wins;          // Winning trades
   int      losses;        // Losing trades
   int      breakevens;    // Breakeven trades
   double   win_rate;      // Win rate %
   double   gross_profit;  // Sum of positive PnL
   double   gross_loss;    // Sum of negative PnL (absolute)
   double   net_pnl;       // Net profit/loss
   double   avg_r;         // Average realized R
   double   max_drawdown;  // Peak drawdown within period
   double   ending_equity; // Simulated equity at end of period

   void Reset(const string p_type = "", const string p_key = "")
   {
      period_type   = p_type;
      period_key    = p_key;
      start_time    = 0;
      end_time      = 0;
      trades        = 0;
      wins          = 0;
      losses        = 0;
      breakevens    = 0;
      win_rate      = 0.0;
      gross_profit  = 0.0;
      gross_loss    = 0.0;
      net_pnl       = 0.0;
      avg_r         = 0.0;
      max_drawdown  = 0.0;
      ending_equity = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Audit Record                                                     |
//+------------------------------------------------------------------+
struct SAuditRecord
{
   datetime              timestamp;
   ENUM_AUDIT_EVENT_TYPE event_type;
   ulong                 trade_id;
   string                symbol;
   string                details;

   void Reset()
   {
      timestamp  = 0;
      event_type = AUDIT_PERSISTENCE_LOAD;
      trade_id   = 0;
      symbol     = "";
      details    = "";
   }

   string Format() const
   {
      return StringFormat("%s | EVENT=%s | TRADE_ID=%I64u | SYMBOL=%s | %s",
         TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
         AuditEventToString(event_type),
         trade_id,
         symbol == "" ? "N/A" : symbol,
         details
      );
   }
};

#endif
