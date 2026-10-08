//+------------------------------------------------------------------+
//| PaperTradingEngine.mqh                                           |
//| NeuroPip - Phase 6                                      |
//| Paper Trading & Trade Simulation Engine                          |
//| MONITOR_ONLY - No execution capability                            |
//+------------------------------------------------------------------+
#ifndef ATG_PAPER_TRADING_ENGINE_MQH
#define ATG_PAPER_TRADING_ENGINE_MQH

#include "PaperTradeTypes.mqh"
#include "PerformanceEngine.mqh"
#include "../Persistence/PersistenceTypes.mqh"
#include "../Persistence/PaperTradeStorage.mqh"
#include "../Persistence/HistoricalAnalyticsEngine.mqh"
#include "../Strategy/TradePlanTypes.mqh"
#include "../Strategy/TradePlanner.mqh"
#include "../MarketData/BarDataManager.mqh"
#include "../MarketData/SymbolUniverseManager.mqh"
#include "../Analytics/ForwardEvidenceEngine.mqh"
#include "../Diagnostics/Logger.mqh"

//+------------------------------------------------------------------+
//| CPaperTradingEngine                                              |
//+------------------------------------------------------------------+
class CPaperTradingEngine
{
private:
   CLogger*                    m_logger;
   CPerformanceEngine*         m_performance;
   CSymbolUniverseManager*     m_universe;
   CPaperTradeStorage*         m_storage;
   CHistoricalAnalyticsEngine* m_analytics;
   CForwardEvidenceEngine*     m_evidence;

   bool                    m_enabled;
   string                  m_same_bar_policy;      // "CONSERVATIVE_SL"
   int                     m_max_holding_sec;      // Default: 3600 (1 hour)
   ulong                   m_trade_counter;

   SPaperTrade             m_active_trades[];

   //+----------------------------------------------------------------+
   //| Find active trade index by plan_id                             |
   //+----------------------------------------------------------------+
   int FindActiveTrade(ulong plan_id)
   {
      for(int i = 0; i < ArraySize(m_active_trades); i++)
      {
         if(m_active_trades[i].source_plan_id == plan_id)
            return i;
      }
      return -1;
   }

   //+----------------------------------------------------------------+
   //| Check if plan has already been simulated (active or history)   |
   //+----------------------------------------------------------------+
   bool IsPlanSimulated(ulong plan_id)
   {
      if(FindActiveTrade(plan_id) >= 0)
         return true;

      if(m_performance != NULL)
      {
         int hist_count = m_performance.GetHistoryCount();
         for(int i = 0; i < hist_count; i++)
         {
            SPaperTrade t;
            if(m_performance.GetTrade(i, t) && t.source_plan_id == plan_id)
               return true;
         }
      }
      return false;
   }

   //+----------------------------------------------------------------+
   //| Remove trade from active list                                  |
   //+----------------------------------------------------------------+
   void RemoveActiveTrade(int index)
   {
      int size = ArraySize(m_active_trades);
      if(index < 0 || index >= size) return;

      for(int i = index; i < size - 1; i++)
      {
         m_active_trades[i] = m_active_trades[i + 1];
      }
      ArrayResize(m_active_trades, size - 1);
   }

   //+----------------------------------------------------------------+
   //| Calculate P&L using broker economics                           |
   //+----------------------------------------------------------------+
   bool CalculatePnL(SPaperTrade &trade)
   {
      ENUM_ORDER_TYPE order_type = (trade.direction == ATG_DIRECTION_BUY)
         ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      double profit = 0.0;
      bool calc_ok = OrderCalcProfit(order_type, trade.symbol, trade.volume,
         trade.entry_price, trade.exit_price, profit);

      if(!calc_ok || profit == 0.0)
      {
         // Fallback to tick economics
         double tick_size  = SymbolInfoDouble(trade.symbol, SYMBOL_TRADE_TICK_SIZE);
         double tick_value = SymbolInfoDouble(trade.symbol, SYMBOL_TRADE_TICK_VALUE);
         if(tick_size > 0.0 && tick_value > 0.0)
         {
            double price_diff = 0.0;
            if(trade.direction == ATG_DIRECTION_BUY)
               price_diff = trade.exit_price - trade.entry_price;
            else
               price_diff = trade.entry_price - trade.exit_price;

            profit = (price_diff / tick_size) * tick_value * trade.volume;
            calc_ok = true;
         }
      }

      trade.gross_pnl       = NormalizeDouble(profit, 2);
      trade.simulated_costs = 0.0; // Initial model: zero slippage, spread in entry
      trade.net_pnl         = trade.gross_pnl - trade.simulated_costs;

      if(trade.risk_money > 0.0)
      {
         trade.realized_r = NormalizeDouble(trade.net_pnl / trade.risk_money, 2);
      }
      else
      {
         trade.realized_r = 0.0;
      }

      return calc_ok;
   }

   //+----------------------------------------------------------------+
   //| Format trade record for explainability                         |
   //+----------------------------------------------------------------+
   void FormatTrade(SPaperTrade &trade)
   {
      int digits = (int)SymbolInfoInteger(trade.symbol, SYMBOL_DIGITS);
      if(digits <= 0) digits = 5;

      string exp = StringFormat("=== PAPER TRADE #%I64u [%s] ===\n", trade.paper_trade_id, trade.StatusToString());
      exp += StringFormat("Symbol:     %s | Strategy: %s\n", trade.symbol, trade.strategy_id);
      exp += StringFormat("Direction:  %s | Volume:   %.4f lots\n", trade.DirectionToString(), trade.volume);
      exp += StringFormat("Entry:      %.*f (%s)\n", digits, trade.entry_price, TimeToString(trade.entry_time, TIME_DATE|TIME_SECONDS));
      exp += StringFormat("Stop Loss:  %.*f | Take Profit: %.*f\n", digits, trade.stop_loss, digits, trade.take_profit);
      exp += StringFormat("Exit:       %.*f (%s) | Reason: %s\n",
         digits, trade.exit_price, TimeToString(trade.exit_time, TIME_DATE|TIME_SECONDS), trade.exit_reason);
      exp += StringFormat("Duration:   %d sec\n", trade.holding_duration_sec);
      exp += StringFormat("Net P&L:    $%.2f (%.2fR) | Planned Risk: $%.2f (R:R Planned: %.2f)\n",
         trade.net_pnl, trade.realized_r, trade.risk_money, trade.planned_rr);
      exp += StringFormat("MAE:        %.1f pts | MFE: %.1f pts\n", trade.mae_points, trade.mfe_points);
      exp += "Execution:  SIMULATED PAPER TRADE ONLY (ZERO LIVE ORDERS)\n";
      exp += "==================================================\n";

      trade.formatted_trade = exp;
   }

public:
   CPaperTradingEngine(CLogger* logger = NULL,
                       CPerformanceEngine* performance = NULL,
                       CSymbolUniverseManager* universe = NULL,
                       CPaperTradeStorage* storage = NULL,
                       CHistoricalAnalyticsEngine* analytics = NULL,
                       CForwardEvidenceEngine* evidence = NULL)
      : m_logger(logger),
        m_performance(performance),
        m_universe(universe),
        m_storage(storage),
        m_analytics(analytics),
        m_evidence(evidence),
        m_enabled(true),
        m_same_bar_policy("CONSERVATIVE_SL"),
        m_max_holding_sec(7200),
        m_trade_counter(6000000)
   {
      ArrayResize(m_active_trades, 0);
   }

   void SetLogger(CLogger* logger)                                      { m_logger = logger; }
   void SetPerformanceEngine(CPerformanceEngine* perf)                  { m_performance = perf; }
   void SetUniverseManager(CSymbolUniverseManager* univ)                { m_universe = univ; }
   void SetStorage(CPaperTradeStorage* storage)                         { m_storage = storage; }
   CPaperTradeStorage* GetStorage() const                               { return m_storage; }
   void SetHistoricalAnalyticsEngine(CHistoricalAnalyticsEngine* an)    { m_analytics = an; }
   CHistoricalAnalyticsEngine* GetHistoricalAnalyticsEngine() const     { return m_analytics; }
   void SetForwardEvidenceEngine(CForwardEvidenceEngine* ev)            { m_evidence = ev; }
   CForwardEvidenceEngine* GetForwardEvidenceEngine() const             { return m_evidence; }

   // Configuration
   void SetEnabled(bool enabled)          { m_enabled = enabled; }
   bool IsEnabled() const                 { return m_enabled; }
   void SetSameBarPolicy(string policy)   { m_same_bar_policy = policy; }
   string GetSameBarPolicy() const        { return m_same_bar_policy; }
   void SetMaxHoldingSec(int sec)         { m_max_holding_sec = sec; }

   int  GetActiveCount() const            { return ArraySize(m_active_trades); }
   bool GetActiveTrade(int idx, SPaperTrade &trade) const
   {
      if(idx < 0 || idx >= ArraySize(m_active_trades)) return false;
      trade = m_active_trades[idx];
      return true;
   }

   //+----------------------------------------------------------------+
   //| Initialize engine & recover active/closed state from storage   |
   //+----------------------------------------------------------------+
   bool Initialize()
   {
      ArrayResize(m_active_trades, 0);

      // Phase 7: Active Trade Recovery & Closed History Loading
      if(m_storage != NULL && m_storage.IsEnabled())
      {
         ulong max_trade_id = m_trade_counter;
         m_storage.LoadActiveTrades(m_active_trades, max_trade_id);
         if(max_trade_id > m_trade_counter)
            m_trade_counter = max_trade_id;

         if(m_performance != NULL)
         {
            SPaperTrade closed_trades[];
            m_storage.LoadClosedTrades(closed_trades, max_trade_id);
            if(max_trade_id > m_trade_counter)
               m_trade_counter = max_trade_id;

            m_performance.RebuildFromHistory(closed_trades);
         }
      }

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "PaperTradingEngine", "INIT_SUCCESS",
            StringFormat("Paper Trading Engine initialized. Enabled=%s | SameBarPolicy=%s | MaxHolding=%ds | ActiveRecovered=%d",
               m_enabled ? "TRUE" : "FALSE", m_same_bar_policy, m_max_holding_sec, ArraySize(m_active_trades)));
      }
      return true;
   }

   //+----------------------------------------------------------------+
   //| Create a new Paper Trade from a valid Trade Plan               |
   //+----------------------------------------------------------------+
   bool CreatePaperTrade(const STradePlan &plan, SPaperTrade &out_trade)
   {
      out_trade.Reset();

      if(!m_enabled)
         return false;

      // Only valid trade plans can be simulated
      if(plan.plan_status != TRADE_PLAN_VALID)
      {
         if(m_logger != NULL)
         {
            m_logger.Log(LOG_LEVEL_DEBUG, "PaperTradingEngine", "PAPER_TRADE_REJECTED",
               StringFormat("Plan #%I64u rejected for paper trading: status=%s",
                  plan.plan_id, plan.StatusToString()));
         }
         return false;
      }

      // Duplicate simulation prevention
      if(IsPlanSimulated(plan.plan_id))
      {
         if(m_logger != NULL)
         {
            m_logger.Log(LOG_LEVEL_DEBUG, "PaperTradingEngine", "PAPER_TRADE_DUPLICATE",
               StringFormat("Plan #%I64u has already been simulated. Suppressing duplicate.", plan.plan_id));
         }
         return false;
      }

      // Check if symbol already has an active paper trade
      for(int i = 0; i < ArraySize(m_active_trades); i++)
      {
         if(m_active_trades[i].symbol == plan.symbol && m_active_trades[i].status == PAPER_OPEN)
         {
            if(m_logger != NULL)
            {
               m_logger.Log(LOG_LEVEL_DEBUG, "PaperTradingEngine", "PAPER_TRADE_BUSY",
                  StringFormat("%s already has an active paper trade (#%I64u). Skipping new entry.",
                     plan.symbol, m_active_trades[i].paper_trade_id));
            }
            return false;
         }
      }

      // Create new paper trade record
      m_trade_counter++;
      out_trade.paper_trade_id       = m_trade_counter;
      out_trade.source_plan_id       = plan.plan_id;
      out_trade.strategy_id          = plan.strategy_id;
      out_trade.symbol               = plan.symbol;
      out_trade.direction            = plan.direction;
      out_trade.primary_timeframe    = plan.primary_timeframe;

      out_trade.entry_time           = TimeCurrent();
      out_trade.source_bar_time      = plan.source_bar_time;
      out_trade.entry_price          = plan.entry_price;
      out_trade.stop_loss            = plan.stop_loss;
      out_trade.take_profit          = plan.take_profit;

      out_trade.volume               = plan.normalized_volume;
      out_trade.risk_money           = plan.risk_money;
      out_trade.equity_at_entry      = (m_performance != NULL) ? m_performance.GetCurrentEquity() : 10000.0;
      out_trade.risk_percent         = plan.risk_percent;
      out_trade.planned_rr           = plan.risk_reward_ratio;

      out_trade.strategy_confidence  = plan.strategy_confidence;
      out_trade.strategy_quality     = plan.strategy_quality;
      out_trade.regime               = plan.regime;
      out_trade.explanation          = plan.supporting_evidence;

      out_trade.status               = PAPER_OPEN;
      out_trade.candidate_only       = true; // HARD SAFETY LOCK

      // Phase 9: Forward Evidence Metadata
      out_trade.dataset_class        = DATASET_FORWARD_LIVE_PAPER;
      out_trade.data_quality         = DATA_QUALITY_VALID;
      out_trade.quality_warning_reason = "NONE";
      out_trade.config_fingerprint   = (m_evidence != NULL) ? m_evidence.GetFingerprint() : "FP-FROZEN";
      out_trade.cohort_id            = (m_evidence != NULL) ? m_evidence.GetCohortId() : "COHORT_01";
      out_trade.entry_spread_points  = (int)SymbolInfoInteger(plan.symbol, SYMBOL_SPREAD);

      // Register into active positions array
      int size = ArraySize(m_active_trades);
      ArrayResize(m_active_trades, size + 1);
      m_active_trades[size] = out_trade;

      // Phase 7: Persist active trade state and equity point
      if(m_storage != NULL && m_storage.IsEnabled())
      {
         m_storage.SaveActiveTrades(m_active_trades);
         m_storage.AppendAudit(AUDIT_PAPER_TRADE_CREATED, out_trade.paper_trade_id, out_trade.symbol,
            StringFormat("Created from Plan #%I64u", plan.plan_id));
         m_storage.AppendAudit(AUDIT_PAPER_TRADE_OPENED, out_trade.paper_trade_id, out_trade.symbol,
            StringFormat("SIMULATED POSITION OPEN | %s @ %.*f | SL=%.*f TP=%.*f | Vol=%.4f",
               out_trade.DirectionToString(),
               (int)SymbolInfoInteger(out_trade.symbol, SYMBOL_DIGITS), out_trade.entry_price,
               (int)SymbolInfoInteger(out_trade.symbol, SYMBOL_DIGITS), out_trade.stop_loss,
               (int)SymbolInfoInteger(out_trade.symbol, SYMBOL_DIGITS), out_trade.take_profit,
               out_trade.volume));

         SEquityPoint pt;
         pt.Reset();
         pt.timestamp    = out_trade.entry_time;
         pt.event_type   = "TRADE_OPEN";
         pt.trade_id     = out_trade.paper_trade_id;
         pt.equity       = (m_performance != NULL) ? m_performance.GetCurrentEquity() : out_trade.equity_at_entry;
         pt.balance      = pt.equity;
         pt.peak_equity  = (m_performance != NULL) ? m_performance.GetPeakEquity() : pt.equity;
         pt.drawdown     = (m_performance != NULL) ? m_performance.GetMaxDrawdown() : 0.0;
         pt.drawdown_pct = (m_performance != NULL) ? m_performance.GetMaxDrawdownPct() : 0.0;
         pt.realized_pnl = 0.0;
         pt.realized_r   = 0.0;
         m_storage.AppendEquityPoint(pt);
      }

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "PaperTradingEngine", "PAPER_TRADE_CREATED",
            StringFormat("Paper trade #%I64u created from Plan #%I64u", out_trade.paper_trade_id, plan.plan_id));
         m_logger.Log(LOG_LEVEL_INFO, "PaperTradingEngine", "PAPER_TRADE_OPENED",
            StringFormat("SIMULATED POSITION OPEN | #%I64u | %s %s @ %.*f | SL=%.*f TP=%.*f | Vol=%.4f Risk=$%.2f (DRY-RUN)",
               out_trade.paper_trade_id, out_trade.symbol, out_trade.DirectionToString(),
               (int)SymbolInfoInteger(out_trade.symbol, SYMBOL_DIGITS), out_trade.entry_price,
               (int)SymbolInfoInteger(out_trade.symbol, SYMBOL_DIGITS), out_trade.stop_loss,
               (int)SymbolInfoInteger(out_trade.symbol, SYMBOL_DIGITS), out_trade.take_profit,
               out_trade.volume, out_trade.risk_money));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Update active trades from market closed-bar data               |
   //| Enforces conservative same-bar SL/TP ambiguity policy          |
   //+----------------------------------------------------------------+
   int UpdateActiveTrades(CBarDataManager &bar_manager)
   {
      int closed_count = 0;
      int i = 0;

      while(i < ArraySize(m_active_trades))
      {
         string symbol = m_active_trades[i].symbol;
         ENUM_TIMEFRAMES tf = m_active_trades[i].primary_timeframe;

         CBarState bar;
         if(!bar_manager.GetLatestBar(symbol, tf, bar))
         {
            i++;
            continue;
         }

         // Only evaluate against closed bars that closed after trade entry
         if(bar.time < m_active_trades[i].source_bar_time)
         {
            i++;
            continue;
         }

         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(point <= 0.0) point = 0.0001;

         // Track MAE and MFE
         if(m_active_trades[i].direction == ATG_DIRECTION_BUY)
         {
            double mfe = (bar.high - m_active_trades[i].entry_price) / point;
            double mae = (m_active_trades[i].entry_price - bar.low) / point;
            if(mfe > m_active_trades[i].mfe_points) m_active_trades[i].mfe_points = NormalizeDouble(mfe, 1);
            if(mae > m_active_trades[i].mae_points) m_active_trades[i].mae_points = NormalizeDouble(mae, 1);
         }
         else if(m_active_trades[i].direction == ATG_DIRECTION_SELL)
         {
            double mfe = (m_active_trades[i].entry_price - bar.low) / point;
            double mae = (bar.high - m_active_trades[i].entry_price) / point;
            if(mfe > m_active_trades[i].mfe_points) m_active_trades[i].mfe_points = NormalizeDouble(mfe, 1);
            if(mae > m_active_trades[i].mae_points) m_active_trades[i].mae_points = NormalizeDouble(mae, 1);
         }

         bool is_closed = false;

         // Check SAME-BAR AMBIGUITY (Section 6)
         bool sl_touched = false;
         bool tp_touched = false;

         if(m_active_trades[i].direction == ATG_DIRECTION_BUY)
         {
            sl_touched = (bar.low <= m_active_trades[i].stop_loss);
            tp_touched = (bar.high >= m_active_trades[i].take_profit);
         }
         else // SELL
         {
            sl_touched = (bar.high >= m_active_trades[i].stop_loss);
            tp_touched = (bar.low <= m_active_trades[i].take_profit);
         }

         if(sl_touched && tp_touched)
         {
            // CRITICAL CONSERVATIVE POLICY: Assume SL was hit first!
            m_active_trades[i].exit_price  = m_active_trades[i].stop_loss;
            m_active_trades[i].exit_time   = bar.time;
            m_active_trades[i].status      = PAPER_CLOSED_SL;
            m_active_trades[i].exit_reason = EXIT_REASON_SAME_BAR_CONSERVATIVE_SL;
            is_closed = true;

            if(m_logger != NULL)
            {
               m_logger.Log(LOG_LEVEL_WARNING, "PaperTradingEngine", "PAPER_TRADE_SAME_BAR_AMBIGUITY",
                  StringFormat("Trade #%I64u (%s): Both SL and TP hit in same bar. Conservative policy: Closed at SL.",
                     m_active_trades[i].paper_trade_id, symbol));
            }
         }
         else if(sl_touched)
         {
            m_active_trades[i].exit_price  = m_active_trades[i].stop_loss;
            m_active_trades[i].exit_time   = bar.time;
            m_active_trades[i].status      = PAPER_CLOSED_SL;
            m_active_trades[i].exit_reason = EXIT_REASON_SL;
            is_closed = true;

            if(m_logger != NULL)
            {
               m_logger.Log(LOG_LEVEL_INFO, "PaperTradingEngine", "PAPER_TRADE_SL",
                  StringFormat("Trade #%I64u (%s) hit Stop Loss @ %.*f",
                     m_active_trades[i].paper_trade_id, symbol,
                     (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS), m_active_trades[i].exit_price));
            }
         }
         else if(tp_touched)
         {
            m_active_trades[i].exit_price  = m_active_trades[i].take_profit;
            m_active_trades[i].exit_time   = bar.time;
            m_active_trades[i].status      = PAPER_CLOSED_TP;
            m_active_trades[i].exit_reason = EXIT_REASON_TP;
            is_closed = true;

            if(m_logger != NULL)
            {
               m_logger.Log(LOG_LEVEL_INFO, "PaperTradingEngine", "PAPER_TRADE_TP",
                  StringFormat("Trade #%I64u (%s) hit Take Profit @ %.*f",
                     m_active_trades[i].paper_trade_id, symbol,
                     (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS), m_active_trades[i].exit_price));
            }
         }
         else if(TimeCurrent() > m_active_trades[i].entry_time + m_max_holding_sec)
         {
            // Position holding duration expired
            m_active_trades[i].exit_price  = bar.close;
            m_active_trades[i].exit_time   = bar.time;
            m_active_trades[i].status      = PAPER_CLOSED_EXPIRY;
            m_active_trades[i].exit_reason = EXIT_REASON_EXPIRY;
            is_closed = true;

            if(m_logger != NULL)
            {
               m_logger.Log(LOG_LEVEL_INFO, "PaperTradingEngine", "PAPER_TRADE_EXPIRED",
                  StringFormat("Trade #%I64u (%s) expired after %d seconds.",
                     m_active_trades[i].paper_trade_id, symbol, m_max_holding_sec));
            }
         }

         if(is_closed)
         {
            m_active_trades[i].holding_duration_sec = (int)(m_active_trades[i].exit_time - m_active_trades[i].entry_time);
            if(m_active_trades[i].holding_duration_sec < 0) m_active_trades[i].holding_duration_sec = 0;

            CalculatePnL(m_active_trades[i]);
            FormatTrade(m_active_trades[i]);

            if(m_logger != NULL)
            {
               m_logger.Log(LOG_LEVEL_INFO, "PaperTradingEngine", "PAPER_TRADE_CLOSED",
                  StringFormat("SIMULATED POSITION CLOSED | #%I64u | %s %s | Exit=%.*f | P&L=$%.2f (%.2fR) | %s",
                     m_active_trades[i].paper_trade_id, symbol, m_active_trades[i].DirectionToString(),
                     (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS), m_active_trades[i].exit_price,
                     m_active_trades[i].net_pnl, m_active_trades[i].realized_r, m_active_trades[i].exit_reason));

               Print(m_active_trades[i].formatted_trade);
            }

            // Transfer to PerformanceEngine
            if(m_performance != NULL)
            {
               m_performance.RecordTrade(m_active_trades[i]);
            }
            if(m_analytics != NULL)
            {
               m_analytics.RecordTrade(m_active_trades[i]);
            }
            if(m_evidence != NULL)
            {
               m_evidence.RecordTrade(m_active_trades[i]);
            }

            // Phase 7: Persist closed trade, equity point, and audit events
            if(m_storage != NULL && m_storage.IsEnabled())
            {
               m_storage.AppendClosedTrade(m_active_trades[i]);

               SEquityPoint pt;
               pt.Reset();
               pt.timestamp    = m_active_trades[i].exit_time;
               pt.event_type   = "TRADE_CLOSE";
               pt.trade_id     = m_active_trades[i].paper_trade_id;
               pt.equity       = (m_performance != NULL) ? m_performance.GetCurrentEquity() : 0.0;
               pt.balance      = pt.equity;
               pt.peak_equity  = (m_performance != NULL) ? m_performance.GetPeakEquity() : pt.equity;
               pt.drawdown     = (m_performance != NULL) ? m_performance.GetMaxDrawdown() : 0.0;
               pt.drawdown_pct = (m_performance != NULL) ? m_performance.GetMaxDrawdownPct() : 0.0;
               pt.realized_pnl = m_active_trades[i].net_pnl;
               pt.realized_r   = m_active_trades[i].realized_r;
               m_storage.AppendEquityPoint(pt);

               ENUM_AUDIT_EVENT_TYPE evt = AUDIT_PAPER_TRADE_CLOSED;
               if(m_active_trades[i].status == PAPER_CLOSED_TP) evt = AUDIT_PAPER_TRADE_TP;
               else if(m_active_trades[i].status == PAPER_CLOSED_SL) evt = AUDIT_PAPER_TRADE_SL;
               else if(m_active_trades[i].status == PAPER_CLOSED_EXPIRY) evt = AUDIT_PAPER_TRADE_EXPIRED;
               if(m_active_trades[i].exit_reason == EXIT_REASON_SAME_BAR_CONSERVATIVE_SL) evt = AUDIT_SAME_BAR_AMBIGUITY;

               m_storage.AppendAudit(evt, m_active_trades[i].paper_trade_id, m_active_trades[i].symbol,
                  StringFormat("SIMULATED POSITION CLOSED | P&L=$%.2f (%.2fR) | %s",
                     m_active_trades[i].net_pnl, m_active_trades[i].realized_r, m_active_trades[i].exit_reason));
            }

            RemoveActiveTrade(i);
            closed_count++;

            // Phase 7: Update active trades on disk
            if(m_storage != NULL && m_storage.IsEnabled())
            {
               m_storage.SaveActiveTrades(m_active_trades);
            }
         }
         else
         {
            i++;
         }
      }

      return closed_count;
   }

   //+----------------------------------------------------------------+
   //| Process on closed-bar events across all universe symbols       |
   //+----------------------------------------------------------------+
   void ProcessOnBar(CTradePlanner &trade_planner, CBarDataManager &bar_manager)
   {
      if(!m_enabled) return;

      // 1. First, update all currently active positions against closed bars
      UpdateActiveTrades(bar_manager);

      // 2. Second, evaluate new valid trade plans from TradePlanner
      int count = m_universe.GetSymbolCount();
      for(int i = 0; i < count; i++)
      {
         if(!m_universe.IsAvailable(i))
            continue;

         string symbol = m_universe.GetBrokerSymbol(i);
         if(symbol == "")
            continue;

         STradePlan plan;
         if(trade_planner.GetLatestPlan(symbol, plan))
         {
            if(plan.plan_status == TRADE_PLAN_VALID)
            {
               SPaperTrade trade;
               CreatePaperTrade(plan, trade);
            }
         }
      }
   }
};

#endif
