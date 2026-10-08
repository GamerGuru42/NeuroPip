//+------------------------------------------------------------------+
//| PerformanceEngine.mqh                                            |
//| ATG Trading Engine - Phase 6                                      |
//| Paper Trading Performance & Equity Tracking Engine               |
//| MONITOR_ONLY - No execution capability                            |
//+------------------------------------------------------------------+
#ifndef ATG_PERFORMANCE_ENGINE_MQH
#define ATG_PERFORMANCE_ENGINE_MQH

#include "PaperTradeTypes.mqh"
#include "../Diagnostics/Logger.mqh"

//+------------------------------------------------------------------+
//| Per-Symbol Performance Summary                                   |
//+------------------------------------------------------------------+
struct SSymbolPerformance
{
   string   symbol;
   int      trades;
   int      wins;
   int      losses;
   int      breakevens;
   double   gross_profit;
   double   gross_loss;
   double   net_pnl;
   double   win_rate;
   double   avg_r;
   double   profit_factor;
   double   max_drawdown;

   void Reset(const string sym = "")
   {
      symbol         = sym;
      trades         = 0;
      wins           = 0;
      losses         = 0;
      breakevens     = 0;
      gross_profit   = 0.0;
      gross_loss     = 0.0;
      net_pnl        = 0.0;
      win_rate       = 0.0;
      avg_r          = 0.0;
      profit_factor  = 0.0;
      max_drawdown   = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Per-Strategy Performance Summary                                 |
//+------------------------------------------------------------------+
struct SStrategyPerformance
{
   string   strategy_id;
   int      trades;
   int      wins;
   int      losses;
   double   net_pnl;
   double   win_rate;
   double   avg_r;
   double   profit_factor;

   void Reset(const string strat = "")
   {
      strategy_id    = strat;
      trades         = 0;
      wins           = 0;
      losses         = 0;
      net_pnl        = 0.0;
      win_rate       = 0.0;
      avg_r          = 0.0;
      profit_factor  = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Per-Regime Performance Summary                                   |
//+------------------------------------------------------------------+
struct SRegimePerformance
{
   ENUM_ATG_MARKET_REGIME regime;
   int                    trades;
   int                    wins;
   int                    losses;
   double                 net_pnl;
   double                 win_rate;
   double                 avg_r;

   void Reset(ENUM_ATG_MARKET_REGIME reg = REGIME_INSUFFICIENT_DATA)
   {
      regime   = reg;
      trades   = 0;
      wins     = 0;
      losses   = 0;
      net_pnl  = 0.0;
      win_rate = 0.0;
      avg_r    = 0.0;
   }
};

//+------------------------------------------------------------------+
//| CPerformanceEngine                                               |
//+------------------------------------------------------------------+
class CPerformanceEngine
{
private:
   CLogger*                m_logger;

   // Equity curve
   double                  m_initial_equity;
   double                  m_current_equity;
   double                  m_peak_equity;
   double                  m_max_drawdown;
   double                  m_max_drawdown_pct;

   // Aggregate counts
   int                     m_total_trades;
   int                     m_winning_trades;
   int                     m_losing_trades;
   int                     m_breakeven_trades;

   // Financial totals
   double                  m_gross_profit;
   double                  m_gross_loss;
   double                  m_net_pnl;
   double                  m_total_r;
   double                  m_total_win_r;
   double                  m_total_loss_r;
   double                  m_total_simulated_risk;
   long                    m_total_duration_sec;

   // Extrema
   double                  m_largest_win;
   double                  m_largest_loss;

   // Streaks
   int                     m_current_win_streak;
   int                     m_current_loss_streak;
   int                     m_max_win_streak;
   int                     m_max_loss_streak;

   // Configuration
   int                     m_min_sample_size;

   // Analytics breakdowns
   SSymbolPerformance      m_symbol_stats[];
   SStrategyPerformance    m_strategy_stats[];
   SRegimePerformance      m_regime_stats[];

   // Full inspectable trade history
   SPaperTrade             m_trade_history[];

   //+----------------------------------------------------------------+
   //| Find or create symbol stat slot                                |
   //+----------------------------------------------------------------+
   int EnsureSymbolSlot(const string symbol)
   {
      for(int i = 0; i < ArraySize(m_symbol_stats); i++)
      {
         if(m_symbol_stats[i].symbol == symbol)
            return i;
      }
      int size = ArraySize(m_symbol_stats);
      ArrayResize(m_symbol_stats, size + 1);
      m_symbol_stats[size].Reset(symbol);
      return size;
   }

   //+----------------------------------------------------------------+
   //| Find or create strategy stat slot                              |
   //+----------------------------------------------------------------+
   int EnsureStrategySlot(const string strategy_id)
   {
      for(int i = 0; i < ArraySize(m_strategy_stats); i++)
      {
         if(m_strategy_stats[i].strategy_id == strategy_id)
            return i;
      }
      int size = ArraySize(m_strategy_stats);
      ArrayResize(m_strategy_stats, size + 1);
      m_strategy_stats[size].Reset(strategy_id);
      return size;
   }

   //+----------------------------------------------------------------+
   //| Find or create regime stat slot                                |
   //+----------------------------------------------------------------+
   int EnsureRegimeSlot(ENUM_ATG_MARKET_REGIME regime)
   {
      for(int i = 0; i < ArraySize(m_regime_stats); i++)
      {
         if(m_regime_stats[i].regime == regime)
            return i;
      }
      int size = ArraySize(m_regime_stats);
      ArrayResize(m_regime_stats, size + 1);
      m_regime_stats[size].Reset(regime);
      return size;
   }

public:
   CPerformanceEngine(CLogger* logger = NULL, double initial_equity = 1000.0, int min_sample_size = 30)
      : m_logger(logger),
        m_initial_equity(initial_equity),
        m_current_equity(initial_equity),
        m_peak_equity(initial_equity),
        m_max_drawdown(0.0),
        m_max_drawdown_pct(0.0),
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
        m_total_simulated_risk(0.0),
        m_total_duration_sec(0),
        m_largest_win(0.0),
        m_largest_loss(0.0),
        m_current_win_streak(0),
        m_current_loss_streak(0),
        m_max_win_streak(0),
        m_max_loss_streak(0),
        m_min_sample_size(min_sample_size)
   {
      ArrayResize(m_symbol_stats, 0);
      ArrayResize(m_strategy_stats, 0);
      ArrayResize(m_regime_stats, 0);
      ArrayResize(m_trade_history, 0);
   }

   void SetLogger(CLogger* logger)                { m_logger = logger; }

   //+----------------------------------------------------------------+
   //| Reset state                                                    |
   //+----------------------------------------------------------------+
   void Reset(double initial_equity = 10000.0)
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
      m_total_simulated_risk = 0.0;
      m_total_duration_sec   = 0;
      m_largest_win          = 0.0;
      m_largest_loss         = 0.0;
      m_current_win_streak   = 0;
      m_current_loss_streak  = 0;
      m_max_win_streak       = 0;
      m_max_loss_streak      = 0;

      ArrayResize(m_symbol_stats, 0);
      ArrayResize(m_strategy_stats, 0);
      ArrayResize(m_regime_stats, 0);
      ArrayResize(m_trade_history, 0);
   }

   // Configuration
   void SetInitialEquity(double eq)     { m_initial_equity = eq; if(m_total_trades == 0) { m_current_equity = eq; m_peak_equity = eq; } }
   void SetMinSampleSize(int sample)    { m_min_sample_size = sample; }
   int  GetMinSampleSize() const        { return m_min_sample_size; }

   //+----------------------------------------------------------------+
   //| Rebuild performance metrics from historical closed trades      |
   //+----------------------------------------------------------------+
   bool RebuildFromHistory(const SPaperTrade &trades[])
   {
      Reset(m_initial_equity);
      int count = ArraySize(trades);
      for(int i = 0; i < count; i++)
      {
         RecordTrade(trades[i]);
      }
      return true;
   }

   // Basic Getters
   double GetInitialEquity() const      { return m_initial_equity; }
   double GetCurrentEquity() const      { return m_current_equity; }
   double GetPeakEquity() const         { return m_peak_equity; }
   double GetMaxDrawdown() const        { return m_max_drawdown; }
   double GetMaxDrawdownPct() const     { return m_max_drawdown_pct; }

   int    GetTotalTrades() const        { return m_total_trades; }
   int    GetWinningTrades() const      { return m_winning_trades; }
   int    GetLosingTrades() const       { return m_losing_trades; }
   int    GetBreakevenTrades() const    { return m_breakeven_trades; }

   double GetGrossProfit() const        { return m_gross_profit; }
   double GetGrossLoss() const          { return m_gross_loss; }
   double GetNetPnL() const             { return m_net_pnl; }
   double GetTotalR() const             { return m_total_r; }
   double GetTotalSimulatedRisk() const { return m_total_simulated_risk; }

   double GetLargestWin() const         { return m_largest_win; }
   double GetLargestLoss() const        { return m_largest_loss; }
   int    GetCurrentWinStreak() const   { return m_current_win_streak; }
   int    GetCurrentLossStreak() const  { return m_current_loss_streak; }
   int    GetMaxWinStreak() const       { return m_max_win_streak; }
   int    GetMaxLossStreak() const      { return m_max_loss_streak; }

   // Calculated Ratios
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
      if(m_gross_loss > 0.0001)
         return NormalizeDouble(m_gross_profit / m_gross_loss, 2);
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

   //+----------------------------------------------------------------+
   //| R-Based Expectancy Calculation                                 |
   //| Expectancy = (Win_Rate * Avg_Win_R) - (Loss_Rate * Avg_Loss_R) |
   //+----------------------------------------------------------------+
   double GetExpectancy() const
   {
      if(m_total_trades == 0) return 0.0;

      double win_rate_dec  = (double)m_winning_trades / m_total_trades;
      double loss_rate_dec = (double)m_losing_trades / m_total_trades;

      double avg_win_r  = (m_winning_trades > 0) ? (m_total_win_r / m_winning_trades) : 0.0;
      double avg_loss_r = (m_losing_trades > 0)  ? (MathAbs(m_total_loss_r) / m_losing_trades) : 0.0;

      double exp = (win_rate_dec * avg_win_r) - (loss_rate_dec * avg_loss_r);
      return NormalizeDouble(exp, 2);
   }

   int GetAverageHoldingDurationSec() const
   {
      return (m_total_trades > 0) ? (int)(m_total_duration_sec / m_total_trades) : 0;
   }

   bool IsSampleSufficient() const
   {
      return (m_total_trades >= m_min_sample_size);
   }

   string GetSampleStatus() const
   {
      return IsSampleSufficient() ? "PERFORMANCE_SAMPLE_READY" : "INSUFFICIENT_SAMPLE";
   }

   //+----------------------------------------------------------------+
   //| Record a completed Paper Trade                                 |
   //+----------------------------------------------------------------+
   void RecordTrade(const SPaperTrade &trade)
   {
      m_total_trades++;
      m_total_simulated_risk += trade.risk_money;
      m_total_duration_sec   += trade.holding_duration_sec;
      m_total_r              += trade.realized_r;

      // Financial outcome
      double pnl = trade.net_pnl;
      m_net_pnl += pnl;

      if(pnl > 0.0001)
      {
         m_winning_trades++;
         m_gross_profit += pnl;
         m_total_win_r  += trade.realized_r;
         if(pnl > m_largest_win) m_largest_win = pnl;

         // Streaks
         m_current_win_streak++;
         m_current_loss_streak = 0;
         if(m_current_win_streak > m_max_win_streak)
            m_max_win_streak = m_current_win_streak;
      }
      else if(pnl < -0.0001)
      {
         m_losing_trades++;
         m_gross_loss += MathAbs(pnl);
         m_total_loss_r += trade.realized_r;
         if(MathAbs(pnl) > m_largest_loss) m_largest_loss = MathAbs(pnl);

         // Streaks
         m_current_loss_streak++;
         m_current_win_streak = 0;
         if(m_current_loss_streak > m_max_loss_streak)
            m_max_loss_streak = m_current_loss_streak;
      }
      else
      {
         m_breakeven_trades++;
      }

      // Equity update
      m_current_equity = m_initial_equity + m_net_pnl;
      if(m_current_equity > m_peak_equity)
      {
         m_peak_equity = m_current_equity;
      }

      // Drawdown calculation
      double current_dd = m_peak_equity - m_current_equity;
      if(current_dd > m_max_drawdown)
      {
         m_max_drawdown = current_dd;
      }

      if(m_peak_equity > 0.0)
      {
         double current_dd_pct = (current_dd / m_peak_equity) * 100.0;
         if(current_dd_pct > m_max_drawdown_pct)
         {
            m_max_drawdown_pct = NormalizeDouble(current_dd_pct, 2);
         }
      }

      // Update Symbol analytics
      int sym_idx = EnsureSymbolSlot(trade.symbol);
      m_symbol_stats[sym_idx].trades++;
      m_symbol_stats[sym_idx].net_pnl += pnl;
      if(pnl > 0.0001)
      {
         m_symbol_stats[sym_idx].wins++;
         m_symbol_stats[sym_idx].gross_profit += pnl;
      }
      else if(pnl < -0.0001)
      {
         m_symbol_stats[sym_idx].losses++;
         m_symbol_stats[sym_idx].gross_loss += MathAbs(pnl);
      }
      else
      {
         m_symbol_stats[sym_idx].breakevens++;
      }
      m_symbol_stats[sym_idx].win_rate = (m_symbol_stats[sym_idx].trades > 0)
         ? NormalizeDouble(((double)m_symbol_stats[sym_idx].wins / m_symbol_stats[sym_idx].trades) * 100.0, 1) : 0.0;
      m_symbol_stats[sym_idx].avg_r = (m_symbol_stats[sym_idx].trades > 0)
         ? NormalizeDouble((m_symbol_stats[sym_idx].net_pnl / (trade.risk_money > 0 ? trade.risk_money : 1.0)) / m_symbol_stats[sym_idx].trades, 2) : 0.0;
      if(m_symbol_stats[sym_idx].gross_loss > 0.0)
         m_symbol_stats[sym_idx].profit_factor = NormalizeDouble(m_symbol_stats[sym_idx].gross_profit / m_symbol_stats[sym_idx].gross_loss, 2);

      // Update Strategy analytics
      int strat_idx = EnsureStrategySlot(trade.strategy_id);
      m_strategy_stats[strat_idx].trades++;
      m_strategy_stats[strat_idx].net_pnl += pnl;
      if(pnl > 0.0001) m_strategy_stats[strat_idx].wins++;
      else if(pnl < -0.0001) m_strategy_stats[strat_idx].losses++;
      m_strategy_stats[strat_idx].win_rate = (m_strategy_stats[strat_idx].trades > 0)
         ? NormalizeDouble(((double)m_strategy_stats[strat_idx].wins / m_strategy_stats[strat_idx].trades) * 100.0, 1) : 0.0;

      // Update Regime analytics
      int reg_idx = EnsureRegimeSlot(trade.regime);
      m_regime_stats[reg_idx].trades++;
      m_regime_stats[reg_idx].net_pnl += pnl;
      if(pnl > 0.0001) m_regime_stats[reg_idx].wins++;
      else if(pnl < -0.0001) m_regime_stats[reg_idx].losses++;
      m_regime_stats[reg_idx].win_rate = (m_regime_stats[reg_idx].trades > 0)
         ? NormalizeDouble(((double)m_regime_stats[reg_idx].wins / m_regime_stats[reg_idx].trades) * 100.0, 1) : 0.0;

      // Append to trade history
      int hist_size = ArraySize(m_trade_history);
      ArrayResize(m_trade_history, hist_size + 1);
      m_trade_history[hist_size] = trade;

      // Structured logging
      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_DEBUG, "PerformanceEngine", "PERFORMANCE_UPDATE",
            StringFormat("Trade #%I64u recorded. P&L=$%.2f (%.2fR) | Total Trades=%d | Eq=$%.2f | DD=%.2f%%",
               trade.paper_trade_id, trade.net_pnl, trade.realized_r,
               m_total_trades, m_current_equity, m_max_drawdown_pct));
      }
   }

   // History Access
   int GetHistoryCount() const { return ArraySize(m_trade_history); }
   bool GetTrade(int index, SPaperTrade &trade) const
   {
      if(index < 0 || index >= ArraySize(m_trade_history)) return false;
      trade = m_trade_history[index];
      return true;
   }

   // Breakdown Accessors
   int GetSymbolStatsCount() const { return ArraySize(m_symbol_stats); }
   bool GetSymbolStats(int index, SSymbolPerformance &stats) const
   {
      if(index < 0 || index >= ArraySize(m_symbol_stats)) return false;
      stats = m_symbol_stats[index];
      return true;
   }

   int GetStrategyStatsCount() const { return ArraySize(m_strategy_stats); }
   bool GetStrategyStats(int index, SStrategyPerformance &stats) const
   {
      if(index < 0 || index >= ArraySize(m_strategy_stats)) return false;
      stats = m_strategy_stats[index];
      return true;
   }

   int GetRegimeStatsCount() const { return ArraySize(m_regime_stats); }
   bool GetRegimeStats(int index, SRegimePerformance &stats) const
   {
      if(index < 0 || index >= ArraySize(m_regime_stats)) return false;
      stats = m_regime_stats[index];
      return true;
   }

   //+----------------------------------------------------------------+
   //| Generate structured performance report                         |
   //+----------------------------------------------------------------+
   string GenerateReport() const
   {
      string rep = "\n==================================================\n";
      rep += "ATG PAPER TRADING PERFORMANCE REPORT (Phase 6)\n";
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
      rep += StringFormat("Largest Win:         $%.2f\n", m_largest_win);
      rep += StringFormat("Largest Loss:        $%.2f\n", m_largest_loss);
      rep += StringFormat("Max Win Streak:      %d (Current: %d)\n", m_max_win_streak, m_current_win_streak);
      rep += StringFormat("Max Loss Streak:     %d (Current: %d)\n", m_max_loss_streak, m_current_loss_streak);
      rep += StringFormat("Total Risk Sized:    $%.2f\n", m_total_simulated_risk);
      rep += StringFormat("Avg Duration:        %d sec\n", GetAverageHoldingDurationSec());

      if(ArraySize(m_symbol_stats) > 0)
      {
         rep += "\n--- SYMBOL BREAKDOWN ---\n";
         for(int i = 0; i < ArraySize(m_symbol_stats); i++)
         {
            rep += StringFormat("%-10s | %2d trades | WinRate: %5.1f%% | PnL: $%8.2f | Avg R: %5.2f\n",
               m_symbol_stats[i].symbol,
               m_symbol_stats[i].trades,
               m_symbol_stats[i].win_rate,
               m_symbol_stats[i].net_pnl,
               m_symbol_stats[i].avg_r);
         }
      }

      if(ArraySize(m_regime_stats) > 0)
      {
         rep += "\n--- REGIME BREAKDOWN ---\n";
         for(int i = 0; i < ArraySize(m_regime_stats); i++)
         {
            rep += StringFormat("%-25s | %2d trades | WinRate: %5.1f%% | PnL: $%8.2f\n",
               EnumToString(m_regime_stats[i].regime),
               m_regime_stats[i].trades,
               m_regime_stats[i].win_rate,
               m_regime_stats[i].net_pnl);
         }
      }

      rep += "\nExecution Safety:    ZERO LIVE ORDERS (can_trade=false, MONITOR_ONLY=true)\n";
      rep += "==================================================\n";
      return rep;
   }
};

#endif
