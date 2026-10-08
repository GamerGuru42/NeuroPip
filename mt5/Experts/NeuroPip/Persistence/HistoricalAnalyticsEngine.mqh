//+------------------------------------------------------------------+
//| HistoricalAnalyticsEngine.mqh                                    |
//| NeuroPip - Phase 7                                      |
//| Historical Performance Analytics & Time-Period Aggregation Engine|
//| MONITOR_ONLY - No execution capability                            |
//+------------------------------------------------------------------+
#ifndef ATG_HISTORICAL_ANALYTICS_ENGINE_MQH
#define ATG_HISTORICAL_ANALYTICS_ENGINE_MQH

#include "PersistenceTypes.mqh"
#include "../Simulation/PaperTradeTypes.mqh"
#include "../Simulation/PerformanceEngine.mqh"
#include "../Diagnostics/Logger.mqh"

//+------------------------------------------------------------------+
//| CHistoricalAnalyticsEngine                                       |
//+------------------------------------------------------------------+
class CHistoricalAnalyticsEngine
{
private:
   CLogger*                m_logger;
   int                     m_min_sample_size;

   // Aggregated Overall Metrics
   int                     m_total_trades;
   int                     m_winning_trades;
   int                     m_losing_trades;
   int                     m_breakeven_trades;
   double                  m_gross_profit;
   double                  m_gross_loss;
   double                  m_net_pnl;
   double                  m_total_r;
   double                  m_total_win_r;
   double                  m_total_loss_r;
   double                  m_largest_win;
   double                  m_largest_loss;
   int                     m_current_win_streak;
   int                     m_current_loss_streak;
   int                     m_max_win_streak;
   int                     m_max_loss_streak;
   long                    m_total_duration_sec;
   int                     m_longest_duration_sec;

   // Equity & Drawdown
   double                  m_initial_equity;
   double                  m_current_equity;
   double                  m_peak_equity;
   double                  m_max_drawdown;
   double                  m_max_drawdown_pct;

   // Categorical breakdowns
   SSymbolPerformance      m_symbol_stats[];
   SStrategyPerformance    m_strategy_stats[];
   SRegimePerformance      m_regime_stats[];

   // Time period breakdowns
   STimePeriodPerformance  m_daily_stats[];
   STimePeriodPerformance  m_weekly_stats[];
   STimePeriodPerformance  m_monthly_stats[];

   //+----------------------------------------------------------------+
   //| Helper: Format date string as YYYY-MM-DD                       |
   //+----------------------------------------------------------------+
   string FormatDate(datetime t) const
   {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);
   }

   //+----------------------------------------------------------------+
   //| Helper: Format week string as YYYY-Www                         |
   //+----------------------------------------------------------------+
   string FormatWeek(datetime t) const
   {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      int week = (dt.day_of_year / 7) + 1;
      return StringFormat("%04d-W%02d", dt.year, week);
   }

   //+----------------------------------------------------------------+
   //| Helper: Format month string as YYYY-MM                         |
   //+----------------------------------------------------------------+
   string FormatMonth(datetime t) const
   {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return StringFormat("%04d-%02d", dt.year, dt.mon);
   }

   //+----------------------------------------------------------------+
   //| Find or create slot in periodic array                          |
   //+----------------------------------------------------------------+
   int EnsurePeriodSlot(STimePeriodPerformance &arr[], const string p_type, const string p_key, datetime t)
   {
      for(int i = 0; i < ArraySize(arr); i++)
      {
         if(arr[i].period_key == p_key)
            return i;
      }
      int size = ArraySize(arr);
      ArrayResize(arr, size + 1);
      arr[size].Reset(p_type, p_key);
      arr[size].start_time = t;
      arr[size].end_time   = t;
      return size;
   }

   int EnsureSymbolSlot(const string sym)
   {
      for(int i = 0; i < ArraySize(m_symbol_stats); i++)
      {
         if(m_symbol_stats[i].symbol == sym) return i;
      }
      int size = ArraySize(m_symbol_stats);
      ArrayResize(m_symbol_stats, size + 1);
      m_symbol_stats[size].Reset(sym);
      return size;
   }

   int EnsureStrategySlot(const string strat)
   {
      for(int i = 0; i < ArraySize(m_strategy_stats); i++)
      {
         if(m_strategy_stats[i].strategy_id == strat) return i;
      }
      int size = ArraySize(m_strategy_stats);
      ArrayResize(m_strategy_stats, size + 1);
      m_strategy_stats[size].Reset(strat);
      return size;
   }

   int EnsureRegimeSlot(ENUM_ATG_MARKET_REGIME reg)
   {
      for(int i = 0; i < ArraySize(m_regime_stats); i++)
      {
         if(m_regime_stats[i].regime == reg) return i;
      }
      int size = ArraySize(m_regime_stats);
      ArrayResize(m_regime_stats, size + 1);
      m_regime_stats[size].Reset(reg);
      return size;
   }

public:
   CHistoricalAnalyticsEngine(CLogger* logger = NULL, int min_sample_size = 30)
      : m_logger(logger),
        m_min_sample_size(min_sample_size),
        m_total_trades(0),
        m_winning_trades(0),
        m_losing_trades(0),
        m_breakeven_trades(0),
        m_gross_profit(0.0),
        m_gross_loss(0.0),
        m_net_pnl(0.0),
        m_total_r(0.0),
        m_total_win_r(0.0),
        m_total_loss_r(0.0),
        m_largest_win(0.0),
        m_largest_loss(0.0),
        m_current_win_streak(0),
        m_current_loss_streak(0),
        m_max_win_streak(0),
        m_max_loss_streak(0),
        m_total_duration_sec(0),
        m_longest_duration_sec(0),
        m_initial_equity(1000.0),
        m_current_equity(1000.0),
        m_peak_equity(1000.0),
        m_max_drawdown(0.0),
        m_max_drawdown_pct(0.0)
   {
      Reset();
   }

   void SetLogger(CLogger* logger)                { m_logger = logger; }
   void SetMinSampleSize(int sample)              { m_min_sample_size = sample; }
   int  GetMinSampleSize() const                  { return m_min_sample_size; }
   bool IsSampleSufficient() const                { return m_total_trades >= m_min_sample_size; }
   string GetSampleStatus() const                 { return IsSampleSufficient() ? "PERFORMANCE_SAMPLE_READY" : "INSUFFICIENT_SAMPLE"; }

   bool Initialize(double initial_equity = 1000.0)
   {
      Reset(initial_equity);
      return true;
   }

   void Reset(double initial_equity = 1000.0)
   {
      m_initial_equity       = initial_equity;
      m_current_equity       = initial_equity;
      m_peak_equity          = initial_equity;
      m_max_drawdown         = 0.0;
      m_max_drawdown_pct     = 0.0;

      m_total_trades         = 0;
      m_winning_trades       = 0;
      m_losing_trades        = 0;
      m_breakeven_trades     = 0;
      m_gross_profit         = 0.0;
      m_gross_loss           = 0.0;
      m_net_pnl              = 0.0;
      m_total_r              = 0.0;
      m_total_win_r          = 0.0;
      m_total_loss_r         = 0.0;
      m_largest_win          = 0.0;
      m_largest_loss         = 0.0;
      m_current_win_streak   = 0;
      m_current_loss_streak  = 0;
      m_max_win_streak       = 0;
      m_max_loss_streak      = 0;
      m_total_duration_sec   = 0;
      m_longest_duration_sec = 0;

      ArrayResize(m_symbol_stats, 0);
      ArrayResize(m_strategy_stats, 0);
      ArrayResize(m_regime_stats, 0);
      ArrayResize(m_daily_stats, 0);
      ArrayResize(m_weekly_stats, 0);
      ArrayResize(m_monthly_stats, 0);
   }

   //+----------------------------------------------------------------+
   //| Record a single closed paper trade                             |
   //+----------------------------------------------------------------+
   void RecordTrade(const SPaperTrade &t)
   {
      if(t.paper_trade_id == 0 || !t.candidate_only)
         return;

      m_total_trades++;
      double pnl = t.net_pnl;
      m_net_pnl += pnl;
      m_total_r += t.realized_r;
      m_total_duration_sec += t.holding_duration_sec;
      if(t.holding_duration_sec > m_longest_duration_sec)
         m_longest_duration_sec = t.holding_duration_sec;

      if(pnl > 0.0001)
      {
         m_winning_trades++;
         m_gross_profit += pnl;
         m_total_win_r  += t.realized_r;
         if(pnl > m_largest_win) m_largest_win = pnl;

         m_current_win_streak++;
         m_current_loss_streak = 0;
         if(m_current_win_streak > m_max_win_streak)
            m_max_win_streak = m_current_win_streak;
      }
      else if(pnl < -0.0001)
      {
         m_losing_trades++;
         m_gross_loss += MathAbs(pnl);
         m_total_loss_r += t.realized_r;
         if(MathAbs(pnl) > m_largest_loss) m_largest_loss = MathAbs(pnl);

         m_current_loss_streak++;
         m_current_win_streak = 0;
         if(m_current_loss_streak > m_max_loss_streak)
            m_max_loss_streak = m_current_loss_streak;
      }
      else
      {
         m_breakeven_trades++;
         m_current_win_streak  = 0;
         m_current_loss_streak = 0;
      }

      // Track equity curve & drawdown
      m_current_equity = m_initial_equity + m_net_pnl;
      if(m_current_equity > m_peak_equity)
         m_peak_equity = m_current_equity;

      double dd = m_peak_equity - m_current_equity;
      if(dd > m_max_drawdown)
         m_max_drawdown = dd;

      double dd_pct = (m_peak_equity > 0.0) ? (dd / m_peak_equity) * 100.0 : 0.0;
      if(dd_pct > m_max_drawdown_pct)
         m_max_drawdown_pct = dd_pct;

      // Symbol stats
      int s_idx = EnsureSymbolSlot(t.symbol);
      m_symbol_stats[s_idx].trades++;
      m_symbol_stats[s_idx].net_pnl += pnl;
      if(pnl > 0.0001) { m_symbol_stats[s_idx].wins++; m_symbol_stats[s_idx].gross_profit += pnl; }
      else if(pnl < -0.0001) { m_symbol_stats[s_idx].losses++; m_symbol_stats[s_idx].gross_loss += MathAbs(pnl); }
      else { m_symbol_stats[s_idx].breakevens++; }
      m_symbol_stats[s_idx].win_rate = (m_symbol_stats[s_idx].trades > 0)
         ? NormalizeDouble(((double)m_symbol_stats[s_idx].wins / m_symbol_stats[s_idx].trades) * 100.0, 1) : 0.0;
      m_symbol_stats[s_idx].avg_r = (m_symbol_stats[s_idx].trades > 0)
         ? NormalizeDouble((m_symbol_stats[s_idx].net_pnl / (t.risk_money > 0 ? t.risk_money : 1.0)) / m_symbol_stats[s_idx].trades, 2) : 0.0;
      if(m_symbol_stats[s_idx].gross_loss > 0.0)
         m_symbol_stats[s_idx].profit_factor = NormalizeDouble(m_symbol_stats[s_idx].gross_profit / m_symbol_stats[s_idx].gross_loss, 2);

      // Strategy stats
      int strat_idx = EnsureStrategySlot(t.strategy_id);
      m_strategy_stats[strat_idx].trades++;
      m_strategy_stats[strat_idx].net_pnl += pnl;
      if(pnl > 0.0001) { m_strategy_stats[strat_idx].wins++; }
      else if(pnl < -0.0001) { m_strategy_stats[strat_idx].losses++; }
      m_strategy_stats[strat_idx].win_rate = (m_strategy_stats[strat_idx].trades > 0)
         ? NormalizeDouble(((double)m_strategy_stats[strat_idx].wins / m_strategy_stats[strat_idx].trades) * 100.0, 1) : 0.0;

      // Regime stats
      int r_idx = EnsureRegimeSlot(t.regime);
      m_regime_stats[r_idx].trades++;
      m_regime_stats[r_idx].net_pnl += pnl;
      if(pnl > 0.0001) { m_regime_stats[r_idx].wins++; }
      else if(pnl < -0.0001) { m_regime_stats[r_idx].losses++; }
      m_regime_stats[r_idx].win_rate = (m_regime_stats[r_idx].trades > 0)
         ? NormalizeDouble(((double)m_regime_stats[r_idx].wins / m_regime_stats[r_idx].trades) * 100.0, 1) : 0.0;

      // Periodic stats
      datetime trade_time = (t.exit_time > 0) ? t.exit_time : t.entry_time;
      if(trade_time == 0) trade_time = TimeCurrent();

      // Daily aggregation
      string day_key = FormatDate(trade_time);
      int d_idx = EnsurePeriodSlot(m_daily_stats, "DAILY", day_key, trade_time);
      m_daily_stats[d_idx].trades++;
      m_daily_stats[d_idx].net_pnl += pnl;
      if(pnl > 0.0001) { m_daily_stats[d_idx].wins++; m_daily_stats[d_idx].gross_profit += pnl; }
      else if(pnl < -0.0001) { m_daily_stats[d_idx].losses++; m_daily_stats[d_idx].gross_loss += MathAbs(pnl); }
      else { m_daily_stats[d_idx].breakevens++; }
      m_daily_stats[d_idx].win_rate = NormalizeDouble(((double)m_daily_stats[d_idx].wins / m_daily_stats[d_idx].trades) * 100.0, 1);
      m_daily_stats[d_idx].ending_equity = m_current_equity;
      m_daily_stats[d_idx].end_time = trade_time;

      // Weekly aggregation
      string week_key = FormatWeek(trade_time);
      int w_idx = EnsurePeriodSlot(m_weekly_stats, "WEEKLY", week_key, trade_time);
      m_weekly_stats[w_idx].trades++;
      m_weekly_stats[w_idx].net_pnl += pnl;
      if(pnl > 0.0001) { m_weekly_stats[w_idx].wins++; m_weekly_stats[w_idx].gross_profit += pnl; }
      else if(pnl < -0.0001) { m_weekly_stats[w_idx].losses++; m_weekly_stats[w_idx].gross_loss += MathAbs(pnl); }
      else { m_weekly_stats[w_idx].breakevens++; }
      m_weekly_stats[w_idx].win_rate = NormalizeDouble(((double)m_weekly_stats[w_idx].wins / m_weekly_stats[w_idx].trades) * 100.0, 1);
      m_weekly_stats[w_idx].ending_equity = m_current_equity;
      m_weekly_stats[w_idx].end_time = trade_time;

      // Monthly aggregation
      string mon_key = FormatMonth(trade_time);
      int m_idx = EnsurePeriodSlot(m_monthly_stats, "MONTHLY", mon_key, trade_time);
      m_monthly_stats[m_idx].trades++;
      m_monthly_stats[m_idx].net_pnl += pnl;
      if(pnl > 0.0001) { m_monthly_stats[m_idx].wins++; m_monthly_stats[m_idx].gross_profit += pnl; }
      else if(pnl < -0.0001) { m_monthly_stats[m_idx].losses++; m_monthly_stats[m_idx].gross_loss += MathAbs(pnl); }
      else { m_monthly_stats[m_idx].breakevens++; }
      m_monthly_stats[m_idx].win_rate = NormalizeDouble(((double)m_monthly_stats[m_idx].wins / m_monthly_stats[m_idx].trades) * 100.0, 1);
      m_monthly_stats[m_idx].ending_equity = m_current_equity;
      m_monthly_stats[m_idx].end_time = trade_time;
   }

   //+----------------------------------------------------------------+
   //| Rebuild all analytics from closed paper trade history          |
   //+----------------------------------------------------------------+
   bool RebuildFromHistory(const SPaperTrade &trades[], double initial_equity = 1000.0)
   {
      Reset(initial_equity);

      int count = ArraySize(trades);
      for(int i = 0; i < count; i++)
      {
         RecordTrade(trades[i]);
      }

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "Analytics", "ANALYTICS_REBUILT",
            StringFormat("Analytics rebuilt: %d trades | Eq=$%.2f | PnL=$%.2f | SampleStatus=%s",
               m_total_trades, m_current_equity, m_net_pnl, GetSampleStatus()));
      }

      return true;
   }

   // Metric Getters
   int    GetTotalTrades() const        { return m_total_trades; }
   int    GetWinningTrades() const      { return m_winning_trades; }
   int    GetLosingTrades() const       { return m_losing_trades; }
   int    GetBreakevenTrades() const    { return m_breakeven_trades; }
   double GetGrossProfit() const        { return m_gross_profit; }
   double GetGrossLoss() const          { return m_gross_loss; }
   double GetNetPnL() const             { return m_net_pnl; }
   double GetCurrentEquity() const      { return m_current_equity; }
   double GetPeakEquity() const         { return m_peak_equity; }
   double GetMaxDrawdown() const        { return m_max_drawdown; }
   double GetMaxDrawdownPct() const     { return m_max_drawdown_pct; }
   int    GetMaxWinStreak() const       { return m_max_win_streak; }
   int    GetMaxLossStreak() const      { return m_max_loss_streak; }
   int    GetLongestDurationSec() const { return m_longest_duration_sec; }

   double GetWinRate() const
   {
      return (m_total_trades > 0) ? NormalizeDouble(((double)m_winning_trades / m_total_trades) * 100.0, 2) : 0.0;
   }
   double GetLossRate() const
   {
      return (m_total_trades > 0) ? NormalizeDouble(((double)m_losing_trades / m_total_trades) * 100.0, 2) : 0.0;
   }
   double GetProfitFactor() const
   {
      if(m_gross_loss > 0.0) return NormalizeDouble(m_gross_profit / m_gross_loss, 2);
      return (m_gross_profit > 0.0) ? 999.0 : 0.0;
   }
   double GetAverageWin() const
   {
      return (m_winning_trades > 0) ? NormalizeDouble(m_gross_profit / m_winning_trades, 2) : 0.0;
   }
   double GetAverageLoss() const
   {
      return (m_losing_trades > 0) ? NormalizeDouble(m_gross_loss / m_losing_trades, 2) : 0.0;
   }
   double GetAverageR() const
   {
      return (m_total_trades > 0) ? NormalizeDouble(m_total_r / m_total_trades, 2) : 0.0;
   }
   double GetExpectancy() const
   {
      if(m_total_trades == 0) return 0.0;
      double win_rate  = (double)m_winning_trades / m_total_trades;
      double loss_rate = (double)m_losing_trades  / m_total_trades;
      double avg_win_r  = (m_winning_trades > 0) ? (m_total_win_r / m_winning_trades) : 0.0;
      double avg_loss_r = (m_losing_trades > 0)  ? (m_total_loss_r / m_losing_trades) : 0.0;
      return NormalizeDouble((win_rate * avg_win_r) - (loss_rate * avg_loss_r), 2);
   }

   // Breakdown accessors
   int GetDailyCount() const            { return ArraySize(m_daily_stats); }
   bool GetDaily(int idx, STimePeriodPerformance &out) const
   {
      if(idx < 0 || idx >= ArraySize(m_daily_stats)) return false;
      out = m_daily_stats[idx];
      return true;
   }

   int GetWeeklyCount() const           { return ArraySize(m_weekly_stats); }
   bool GetWeekly(int idx, STimePeriodPerformance &out) const
   {
      if(idx < 0 || idx >= ArraySize(m_weekly_stats)) return false;
      out = m_weekly_stats[idx];
      return true;
   }

   int GetMonthlyCount() const          { return ArraySize(m_monthly_stats); }
   bool GetMonthly(int idx, STimePeriodPerformance &out) const
   {
      if(idx < 0 || idx >= ArraySize(m_monthly_stats)) return false;
      out = m_monthly_stats[idx];
      return true;
   }

   //+----------------------------------------------------------------+
   //| Generate historical summary and periodic report                |
   //+----------------------------------------------------------------+
   string GenerateHistoricalReport() const
   {
      string rep = "\n==================================================\n";
      rep += "ATG HISTORICAL PAPER ANALYTICS (Phase 7 Persistent)\n";
      rep += "==================================================\n";
      rep += StringFormat("Sample Status:       %s (Sample: %d / %d minimum)\n",
         GetSampleStatus(), m_total_trades, m_min_sample_size);
      rep += StringFormat("Initial Equity:      $%.2f\n", m_initial_equity);
      rep += StringFormat("Current Equity:      $%.2f\n", m_current_equity);
      rep += StringFormat("Peak Equity:         $%.2f\n", m_peak_equity);
      rep += StringFormat("Net P&L:             $%.2f\n", m_net_pnl);
      rep += StringFormat("Maximum Drawdown:    $%.2f (%.2f%%)\n", m_max_drawdown, m_max_drawdown_pct);

      rep += "\n--- TRADE STATISTICS ---\n";
      rep += StringFormat("Total Trades:        %d\n", m_total_trades);
      rep += StringFormat("Winning Trades:      %d (Win Rate: %.2f%%)\n", m_winning_trades, GetWinRate());
      rep += StringFormat("Losing Trades:       %d (Loss Rate: %.2f%%)\n", m_losing_trades, GetLossRate());
      rep += StringFormat("Breakeven Trades:    %d\n", m_breakeven_trades);
      rep += StringFormat("Gross Profit:        $%.2f\n", m_gross_profit);
      rep += StringFormat("Gross Loss:          $%.2f\n", m_gross_loss);
      rep += StringFormat("Profit Factor:       %.2f\n", GetProfitFactor());
      rep += StringFormat("Average Win:         $%.2f\n", GetAverageWin());
      rep += StringFormat("Average Loss:        $%.2f\n", GetAverageLoss());
      rep += StringFormat("Average R:           %.2fR\n", GetAverageR());
      rep += StringFormat("Expectancy:          %.2fR\n", GetExpectancy());
      rep += StringFormat("Max Win Streak:      %d\n", m_max_win_streak);
      rep += StringFormat("Max Loss Streak:     %d\n", m_max_loss_streak);
      rep += StringFormat("Longest Duration:    %d sec\n", m_longest_duration_sec);

      if(ArraySize(m_daily_stats) > 0)
      {
         rep += "\n--- DAILY PERFORMANCE (Last 5 Days) ---\n";
         int start_idx = MathMax(0, ArraySize(m_daily_stats) - 5);
         for(int i = start_idx; i < ArraySize(m_daily_stats); i++)
         {
            rep += StringFormat("%-10s | %2d trades | WinRate: %5.1f%% | PnL: $%8.2f | Eq: $%8.2f\n",
               m_daily_stats[i].period_key,
               m_daily_stats[i].trades,
               m_daily_stats[i].win_rate,
               m_daily_stats[i].net_pnl,
               m_daily_stats[i].ending_equity);
         }
      }

      if(ArraySize(m_weekly_stats) > 0)
      {
         rep += "\n--- WEEKLY PERFORMANCE ---\n";
         for(int i = 0; i < ArraySize(m_weekly_stats); i++)
         {
            rep += StringFormat("%-10s | %2d trades | WinRate: %5.1f%% | PnL: $%8.2f | Eq: $%8.2f\n",
               m_weekly_stats[i].period_key,
               m_weekly_stats[i].trades,
               m_weekly_stats[i].win_rate,
               m_weekly_stats[i].net_pnl,
               m_weekly_stats[i].ending_equity);
         }
      }

      if(ArraySize(m_monthly_stats) > 0)
      {
         rep += "\n--- MONTHLY PERFORMANCE ---\n";
         for(int i = 0; i < ArraySize(m_monthly_stats); i++)
         {
            rep += StringFormat("%-10s | %2d trades | WinRate: %5.1f%% | PnL: $%8.2f | Eq: $%8.2f\n",
               m_monthly_stats[i].period_key,
               m_monthly_stats[i].trades,
               m_monthly_stats[i].win_rate,
               m_monthly_stats[i].net_pnl,
               m_monthly_stats[i].ending_equity);
         }
      }

      rep += "\nExecution Safety:    ZERO LIVE ORDERS (can_trade=false, MONITOR_ONLY=true)\n";
      rep += "==================================================\n";
      return rep;
   }
};

#endif
