//+------------------------------------------------------------------+
//| StatisticalEvaluationEngine.mqh                                  |
//| NeuroPip - Phase 8                                     |
//| Extended Paper Validation & Statistical Evaluation Engine        |
//| MONITOR_ONLY - No execution capability                           |
//+------------------------------------------------------------------+
#ifndef ATG_STATISTICAL_EVALUATION_ENGINE_MQH
#define ATG_STATISTICAL_EVALUATION_ENGINE_MQH

#include "EvaluationTypes.mqh"
#include "../Diagnostics/Logger.mqh"
#include "../Simulation/PaperTradeTypes.mqh"
#include "../Persistence/PersistenceTypes.mqh"
#include "../Intelligence/MarketRegimeTypes.mqh"
#include "../Execution/TradeTypes.mqh"

//+------------------------------------------------------------------+
//| CStatisticalEvaluationEngine                                     |
//+------------------------------------------------------------------+
class CStatisticalEvaluationEngine
{
private:
   CLogger*                m_logger;
   SPhase8EvaluationResult m_last_result;

   // Helper: Linear interpolation percentile on sorted array
   double GetPercentile(const double &sorted[], double pct) const
   {
      int n = ArraySize(sorted);
      if(n <= 0) return 0.0;
      if(n == 1) return sorted[0];
      if(pct <= 0.0) return sorted[0];
      if(pct >= 1.0) return sorted[n - 1];

      double idx = pct * (double)(n - 1);
      int lower = (int)MathFloor(idx);
      int upper = (int)MathCeil(idx);
      double fraction = idx - (double)lower;

      if(lower == upper)
         return sorted[lower];

      return sorted[lower] + fraction * (sorted[upper] - sorted[lower]);
   }

public:
   CStatisticalEvaluationEngine(CLogger* logger = NULL)
      : m_logger(logger)
   {
   }

   void SetLogger(CLogger* logger) { m_logger = logger; }

   //+----------------------------------------------------------------+
   //| Step 1: Validate Dataset Integrity & Completeness              |
   //+----------------------------------------------------------------+
   void ValidateDataset(const SPaperTrade &trades[], SDatasetValidationReport &report)
   {
      report.Reset();
      int total = ArraySize(trades);
      report.total_records = total;

      if(total == 0)
      {
         report.status = DATASET_STATUS_EMPTY;
         report.validation_notes = "Dataset contains 0 records.";
         return;
      }

      string symbols_seen[];
      string strategies_seen[];
      ulong  ids_seen[];

      datetime min_time = 0;
      datetime max_time = 0;

      for(int i = 0; i < total; i++)
      {
         bool record_valid = true;
         SPaperTrade t = trades[i];

         // Check 1: Valid ID
         if(t.paper_trade_id == 0)
         {
            record_valid = false;
            report.missing_fields_count++;
         }

         // Check 2: Duplicate ID
         bool is_dup = false;
         for(int d = 0; d < ArraySize(ids_seen); d++)
         {
            if(ids_seen[d] == t.paper_trade_id)
            {
               is_dup = true;
               break;
            }
         }
         if(is_dup)
         {
            record_valid = false;
            report.duplicates_count++;
         }
         else if(t.paper_trade_id > 0)
         {
            int id_cnt = ArraySize(ids_seen);
            ArrayResize(ids_seen, id_cnt + 1);
            ids_seen[id_cnt] = t.paper_trade_id;
         }

         // Check 3: Price validity
         if(t.entry_price <= 0.0 || t.stop_loss <= 0.0 || t.take_profit <= 0.0 || t.exit_price <= 0.0)
         {
            record_valid = false;
            report.missing_fields_count++;
         }

         // Check 4: Temporal integrity
         if(t.entry_time == 0 || (t.exit_time > 0 && t.exit_time < t.entry_time))
         {
            record_valid = false;
         }

         // Check 5: Risk parameters
         if(t.risk_money <= 0.0 || t.volume <= 0.0)
         {
            record_valid = false;
         }

         if(record_valid)
         {
            report.valid_records++;

            if(min_time == 0 || t.entry_time < min_time) min_time = t.entry_time;
            if(t.exit_time > max_time) max_time = t.exit_time;
            if(t.entry_time > max_time) max_time = t.entry_time;

            // Track unique symbols
            bool sym_found = false;
            for(int s = 0; s < ArraySize(symbols_seen); s++)
            {
               if(symbols_seen[s] == t.symbol) { sym_found = true; break; }
            }
            if(!sym_found && t.symbol != "")
            {
               int sc = ArraySize(symbols_seen);
               ArrayResize(symbols_seen, sc + 1);
               symbols_seen[sc] = t.symbol;
            }

            // Track unique strategies
            bool strat_found = false;
            for(int st = 0; st < ArraySize(strategies_seen); st++)
            {
               if(strategies_seen[st] == t.strategy_id) { strat_found = true; break; }
            }
            if(!strat_found && t.strategy_id != "")
            {
               int stc = ArraySize(strategies_seen);
               ArrayResize(strategies_seen, stc + 1);
               strategies_seen[stc] = t.strategy_id;
            }
         }
         else
         {
            report.rejected_records++;
         }
      }

      report.data_start     = min_time;
      report.data_end       = max_time;
      report.symbol_count   = ArraySize(symbols_seen);
      report.strategy_count = ArraySize(strategies_seen);

      if(report.rejected_records == 0 && report.valid_records >= 15)
      {
         report.status = DATASET_STATUS_VALID;
         report.validation_notes = "Dataset passed all integrity checks cleanly.";
      }
      else if(report.rejected_records > 0 && report.valid_records > 0)
      {
         report.status = DATASET_STATUS_PARTIAL_ANOMALIES;
         report.validation_notes = StringFormat("Found %d anomalous records (%d duplicates, %d missing fields).",
            report.rejected_records, report.duplicates_count, report.missing_fields_count);
      }
      else if(report.valid_records < 15 && report.valid_records > 0)
      {
         report.status = DATASET_STATUS_INSUFFICIENT;
         report.validation_notes = StringFormat("Only %d valid records; below minimum statistical threshold of 15.", report.valid_records);
      }
      else
      {
         report.status = DATASET_STATUS_CORRUPTED;
         report.validation_notes = "Dataset corrupted; zero valid records passed validation.";
      }

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "StatisticalEvaluation", "DATASET_VALIDATED",
            StringFormat("Validation Status: %s | Total=%d Valid=%d Rej=%d Symbols=%d",
               DatasetStatusToString(report.status), report.total_records, report.valid_records,
               report.rejected_records, report.symbol_count));
      }
   }

   //+----------------------------------------------------------------+
   //| Step 2: Distribution Metrics (Mean, Median, SD, Percentiles)   |
   //+----------------------------------------------------------------+
   void CalculateDistribution(const double &values[], SDistributionMetrics &dist)
   {
      dist.Reset();
      int n = ArraySize(values);
      dist.count = n;
      if(n <= 0) return;

      double sum = 0.0;
      for(int i = 0; i < n; i++)
         sum += values[i];

      dist.mean = sum / (double)n;

      double var_sum = 0.0;
      for(int i = 0; i < n; i++)
      {
         double diff = values[i] - dist.mean;
         var_sum += (diff * diff);
      }
      dist.std_dev = (n > 1) ? MathSqrt(var_sum / (double)(n - 1)) : 0.0;

      // Copy and sort
      double sorted[];
      ArrayResize(sorted, n);
      ArrayCopy(sorted, values);
      ArraySort(sorted);

      dist.min_val = sorted[0];
      dist.max_val = sorted[n - 1];
      dist.p10     = GetPercentile(sorted, 0.10);
      dist.p25     = GetPercentile(sorted, 0.25);
      dist.median  = GetPercentile(sorted, 0.50);
      dist.p75     = GetPercentile(sorted, 0.75);
      dist.p90     = GetPercentile(sorted, 0.90);
   }

   //+----------------------------------------------------------------+
   //| Step 3: Overall Performance & Distributions Calculation        |
   //+----------------------------------------------------------------+
   void EvaluateOverallPerformance(const SPaperTrade &trades[], SPhase8EvaluationResult &result, double initial_equity = 1000.0)
   {
      result.ResetCorePerformance();

      int total = ArraySize(trades);
      double r_values[];
      double pnl_values[];
      double duration_values[];

      ArrayResize(r_values, 0);
      ArrayResize(pnl_values, 0);
      ArrayResize(duration_values, 0);

      double current_eq = initial_equity;
      double peak_eq    = initial_equity;
      double max_dd     = 0.0;
      double max_dd_pct = 0.0;

      int cur_win_streak = 0;
      int cur_loss_streak = 0;
      long total_duration = 0;

      double sum_win_pnl = 0.0;
      double sum_loss_pnl = 0.0;
      double sum_win_r = 0.0;
      double sum_loss_r = 0.0;

      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         if(t.paper_trade_id == 0 || !t.candidate_only)
            continue;

         result.total_trades++;
         double pnl = t.net_pnl;
         result.net_pnl += pnl;

         int idx = ArraySize(r_values);
         ArrayResize(r_values, idx + 1);
         ArrayResize(pnl_values, idx + 1);
         ArrayResize(duration_values, idx + 1);

         r_values[idx]        = t.realized_r;
         pnl_values[idx]      = pnl;
         duration_values[idx] = (double)t.holding_duration_sec;

         total_duration += t.holding_duration_sec;
         if(t.holding_duration_sec > result.longest_duration_sec)
            result.longest_duration_sec = t.holding_duration_sec;

         if(pnl > 0.0001)
         {
            result.winning_trades++;
            result.gross_profit += pnl;
            sum_win_pnl += pnl;
            sum_win_r += t.realized_r;

            cur_win_streak++;
            cur_loss_streak = 0;
            if(cur_win_streak > result.max_win_streak)
               result.max_win_streak = cur_win_streak;
         }
         else if(pnl < -0.0001)
         {
            result.losing_trades++;
            result.gross_loss += MathAbs(pnl);
            sum_loss_pnl += MathAbs(pnl);
            sum_loss_r += MathAbs(t.realized_r);

            cur_loss_streak++;
            cur_win_streak = 0;
            if(cur_loss_streak > result.max_loss_streak)
               result.max_loss_streak = cur_loss_streak;
         }
         else
         {
            result.breakeven_trades++;
            cur_win_streak = 0;
            cur_loss_streak = 0;
         }

         // Track equity curve
         current_eq += pnl;
         if(current_eq > peak_eq) peak_eq = current_eq;
         double dd = peak_eq - current_eq;
         if(dd > max_dd) max_dd = dd;
         double dd_pct = (peak_eq > 0.0) ? (dd / peak_eq) * 100.0 : 0.0;
         if(dd_pct > max_dd_pct) max_dd_pct = dd_pct;
      }

      if(result.total_trades > 0)
      {
         result.win_rate  = NormalizeDouble(((double)result.winning_trades / (double)result.total_trades) * 100.0, 2);
         result.loss_rate = NormalizeDouble(((double)result.losing_trades / (double)result.total_trades) * 100.0, 2);
         result.avg_win   = (result.winning_trades > 0) ? NormalizeDouble(sum_win_pnl / (double)result.winning_trades, 2) : 0.0;
         result.avg_loss  = (result.losing_trades > 0)  ? NormalizeDouble(sum_loss_pnl / (double)result.losing_trades, 2) : 0.0;

         result.profit_factor = (result.gross_loss > 0.0)
            ? NormalizeDouble(result.gross_profit / result.gross_loss, 2)
            : (result.gross_profit > 0.0 ? 99.99 : 0.0);

         result.avg_duration_sec = (int)(total_duration / result.total_trades);
         result.max_drawdown     = NormalizeDouble(max_dd, 2);
         result.max_drawdown_pct = NormalizeDouble(max_dd_pct, 2);

         // Expectancy in R: (WinRate * AvgWinR) - (LossRate * AvgLossR)
         double win_p = (double)result.winning_trades / (double)result.total_trades;
         double loss_p = (double)result.losing_trades / (double)result.total_trades;
         double avg_win_r = (result.winning_trades > 0) ? sum_win_r / (double)result.winning_trades : 0.0;
         double avg_loss_r = (result.losing_trades > 0) ? sum_loss_r / (double)result.losing_trades : 0.0;
         result.expectancy = NormalizeDouble((win_p * avg_win_r) - (loss_p * avg_loss_r), 3);
      }

      // Distributions
      CalculateDistribution(r_values, result.r_distribution);
      CalculateDistribution(pnl_values, result.pnl_distribution);
      CalculateDistribution(duration_values, result.duration_distribution);

      result.avg_r    = NormalizeDouble(result.r_distribution.mean, 3);
      result.median_r = NormalizeDouble(result.r_distribution.median, 3);

      // Classify sample tier
      if(result.total_trades < 15)
         result.sample_tier = SAMPLE_INSUFFICIENT;
      else if(result.total_trades < 30)
         result.sample_tier = SAMPLE_PRELIMINARY;
      else
         result.sample_tier = SAMPLE_ADEQUATE_FOR_EVALUATION;
   }

   //+----------------------------------------------------------------+
   //| Step 4: Per-Symbol Breakdown                                   |
   //+----------------------------------------------------------------+
   void EvaluateSymbols(const SPaperTrade &trades[], SSymbolEvaluation &evals[])
   {
      ArrayResize(evals, 0);
      int total = ArraySize(trades);

      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         if(t.paper_trade_id == 0 || !t.candidate_only || t.symbol == "")
            continue;

         int slot = -1;
         for(int s = 0; s < ArraySize(evals); s++)
         {
            if(evals[s].symbol == t.symbol) { slot = s; break; }
         }
         if(slot < 0)
         {
            slot = ArraySize(evals);
            ArrayResize(evals, slot + 1);
            evals[slot].Reset(t.symbol);
         }

         evals[slot].sample_size++;
         double pnl = t.net_pnl;
         evals[slot].net_pnl += pnl;

         if(pnl > 0.0001)
         {
            evals[slot].wins++;
            evals[slot].gross_profit += pnl;
         }
         else if(pnl < -0.0001)
         {
            evals[slot].losses++;
            evals[slot].gross_loss += MathAbs(pnl);
         }
         else
         {
            evals[slot].breakevens++;
         }
      }

      // Compute ratios per symbol
      for(int s = 0; s < ArraySize(evals); s++)
      {
         int n = evals[s].sample_size;
         if(n > 0)
         {
            evals[s].win_rate  = NormalizeDouble(((double)evals[s].wins / (double)n) * 100.0, 2);
            evals[s].loss_rate = NormalizeDouble(((double)evals[s].losses / (double)n) * 100.0, 2);
            evals[s].profit_factor = (evals[s].gross_loss > 0.0)
               ? NormalizeDouble(evals[s].gross_profit / evals[s].gross_loss, 2)
               : (evals[s].gross_profit > 0.0 ? 99.99 : 0.0);

            if(n < 15) evals[s].sample_tier = SAMPLE_INSUFFICIENT;
            else if(n < 30) evals[s].sample_tier = SAMPLE_PRELIMINARY;
            else evals[s].sample_tier = SAMPLE_ADEQUATE_FOR_EVALUATION;
         }
      }
   }

   //+----------------------------------------------------------------+
   //| Step 5: Per-Regime Breakdown                                   |
   //+----------------------------------------------------------------+
   void EvaluateRegimes(const SPaperTrade &trades[], SRegimeEvaluation &evals[])
   {
      ArrayResize(evals, 0);
      int total = ArraySize(trades);

      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         if(t.paper_trade_id == 0 || !t.candidate_only)
            continue;

         int slot = -1;
         for(int r = 0; r < ArraySize(evals); r++)
         {
            if(evals[r].regime == t.regime) { slot = r; break; }
         }
         if(slot < 0)
         {
            slot = ArraySize(evals);
            ArrayResize(evals, slot + 1);
            evals[slot].Reset(t.regime);
         }

         evals[slot].trades++;
         double pnl = t.net_pnl;
         evals[slot].net_pnl += pnl;

         if(pnl > 0.0001) evals[slot].wins++;
         else if(pnl < -0.0001) evals[slot].losses++;

         if(t.direction == ATG_DIRECTION_BUY) evals[slot].buy_count++;
         else if(t.direction == ATG_DIRECTION_SELL) evals[slot].sell_count++;
      }

      for(int r = 0; r < ArraySize(evals); r++)
      {
         int n = evals[r].trades;
         if(n > 0)
         {
            evals[r].win_rate = NormalizeDouble(((double)evals[r].wins / (double)n) * 100.0, 2);
         }
      }
   }

   //+----------------------------------------------------------------+
   //| Step 6: Directional Breakdown (BUY vs SELL)                    |
   //+----------------------------------------------------------------+
   void EvaluateDirections(const SPaperTrade &trades[], SDirectionEvaluation &evals[])
   {
      evals[0].Reset(ATG_DIRECTION_BUY);
      evals[1].Reset(ATG_DIRECTION_SELL);

      double buy_r_sum = 0.0;
      double sell_r_sum = 0.0;
      double buy_gross_profit = 0.0;
      double buy_gross_loss = 0.0;
      double sell_gross_profit = 0.0;
      double sell_gross_loss = 0.0;

      int total = ArraySize(trades);
      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         if(t.paper_trade_id == 0 || !t.candidate_only)
            continue;

         int idx = (t.direction == ATG_DIRECTION_SELL) ? 1 : 0;
         evals[idx].trades++;
         double pnl = t.net_pnl;
         evals[idx].net_pnl += pnl;

         if(idx == 0) buy_r_sum += t.realized_r;
         else sell_r_sum += t.realized_r;

         if(pnl > 0.0001)
         {
            evals[idx].wins++;
            if(idx == 0) buy_gross_profit += pnl;
            else sell_gross_profit += pnl;
         }
         else if(pnl < -0.0001)
         {
            evals[idx].losses++;
            if(idx == 0) buy_gross_loss += MathAbs(pnl);
            else sell_gross_loss += MathAbs(pnl);
         }
      }

      for(int d = 0; d < 2; d++)
      {
         int n = evals[d].trades;
         if(n > 0)
         {
            evals[d].win_rate = NormalizeDouble(((double)evals[d].wins / (double)n) * 100.0, 2);
            evals[d].avg_r    = NormalizeDouble((d == 0 ? buy_r_sum : sell_r_sum) / (double)n, 3);
            double gp = (d == 0) ? buy_gross_profit : sell_gross_profit;
            double gl = (d == 0) ? buy_gross_loss : sell_gross_loss;
            evals[d].profit_factor = (gl > 0.0) ? NormalizeDouble(gp / gl, 2) : (gp > 0.0 ? 99.99 : 0.0);
            evals[d].expectancy    = evals[d].avg_r;
         }
      }
   }

   //+----------------------------------------------------------------+
   //| Step 7: Equity Curve Analysis & Volatility                     |
   //+----------------------------------------------------------------+
   void EvaluateEquityCurve(const SPaperTrade &trades[], double initial_equity, SEquityCurveAnalysis &analysis)
   {
      analysis.Reset();
      analysis.initial_equity = initial_equity;
      analysis.final_equity   = initial_equity;
      analysis.peak_equity    = initial_equity;

      int total = ArraySize(trades);
      if(total == 0) return;

      double cur_equity = initial_equity;
      double peak_equity = initial_equity;
      double max_dd = 0.0;
      double max_dd_pct = 0.0;

      int cur_wins = 0;
      int cur_losses = 0;
      int max_wins = 0;
      int max_losses = 0;

      double returns[];
      ArrayResize(returns, 0);

      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         if(t.paper_trade_id == 0 || !t.candidate_only)
            continue;

         cur_equity += t.net_pnl;

         int r_idx = ArraySize(returns);
         ArrayResize(returns, r_idx + 1);
         returns[r_idx] = t.net_pnl;

         if(cur_equity > peak_equity)
            peak_equity = cur_equity;

         double dd = peak_equity - cur_equity;
         if(dd > max_dd) max_dd = dd;

         double dd_pct = (peak_equity > 0.0) ? (dd / peak_equity) * 100.0 : 0.0;
         if(dd_pct > max_dd_pct) max_dd_pct = dd_pct;

         if(t.net_pnl > 0.0001)
         {
            cur_wins++;
            cur_losses = 0;
            if(cur_wins > max_wins) max_wins = cur_wins;
         }
         else if(t.net_pnl < -0.0001)
         {
            cur_losses++;
            cur_wins = 0;
            if(cur_losses > max_losses) max_losses = cur_losses;
         }
         else
         {
            cur_wins = 0;
            cur_losses = 0;
         }
      }

      analysis.final_equity           = cur_equity;
      analysis.peak_equity            = peak_equity;
      analysis.net_pnl                = cur_equity - initial_equity;
      analysis.max_drawdown           = NormalizeDouble(max_dd, 2);
      analysis.max_drawdown_pct       = NormalizeDouble(max_dd_pct, 2);
      analysis.max_consecutive_wins   = max_wins;
      analysis.max_consecutive_losses = max_losses;
      analysis.recovery_factor        = (max_dd > 0.0) ? NormalizeDouble(analysis.net_pnl / max_dd, 2) : 0.0;

      // Volatility of returns
      int rn = ArraySize(returns);
      if(rn > 1)
      {
         double r_sum = 0.0;
         for(int i = 0; i < rn; i++) r_sum += returns[i];
         double r_mean = r_sum / (double)rn;
         double r_var = 0.0;
         for(int i = 0; i < rn; i++)
         {
            double diff = returns[i] - r_mean;
            r_var += (diff * diff);
         }
         analysis.equity_volatility = NormalizeDouble(MathSqrt(r_var / (double)(rn - 1)), 2);
      }
   }

   //+----------------------------------------------------------------+
   //| Step 8: Risk Contract Validation & Invariants Audit            |
   //+----------------------------------------------------------------+
   void ValidateRiskContract(const SPaperTrade &trades[], SRiskValidationReport &report)
   {
      report.Reset();
      int total = ArraySize(trades);
      report.total_audited = total;

      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         if(t.paper_trade_id == 0 || !t.candidate_only)
            continue;

         bool trade_ok = true;

         // Invariant 1: Risk percent <= 2.0%
         if(t.risk_percent > 0.0 && t.risk_percent <= 2.0)
            report.valid_risk_percent_count++;
         else
         {
            trade_ok = false;
            report.violations_count++;
            report.violation_details = StringFormat("Trade %I64u: invalid risk_percent=%.2f", t.paper_trade_id, t.risk_percent);
         }

         // Invariant 2: Risk money > $0
         if(t.risk_money > 0.0)
            report.valid_risk_money_count++;
         else
         {
            trade_ok = false;
            report.violations_count++;
            report.violation_details = StringFormat("Trade %I64u: invalid risk_money=%.2f", t.paper_trade_id, t.risk_money);
         }

         // Invariant 3: Volume step
         if(t.volume >= 0.01)
            report.valid_lot_step_count++;
         else
         {
            trade_ok = false;
            report.violations_count++;
         }

         // Invariant 4: Stop distance
         if(MathAbs(t.entry_price - t.stop_loss) > 0.0)
            report.valid_stop_distance_count++;
         else
         {
            trade_ok = false;
            report.violations_count++;
         }

         // Invariant 5: Planned R:R >= 1.49
         if(t.planned_rr >= 1.49)
            report.valid_min_rr_count++;
         else
         {
            trade_ok = false;
            report.violations_count++;
         }

         // Invariant 6: Cost simulation validity
         if(t.simulated_costs >= 0.0)
            report.valid_spread_count++;
         else
         {
            trade_ok = false;
            report.violations_count++;
         }
      }
   }

   //+----------------------------------------------------------------+
   //| Step 9: Trade Quality & Confidence Correlation                 |
   //+----------------------------------------------------------------+
   void AnalyzeTradeQuality(const SPaperTrade &trades[], STradeQualityAnalysis &analysis)
   {
      analysis.Reset();
      int total = ArraySize(trades);
      analysis.total_trades = total;

      double high_conf_r_sum = 0.0;
      double low_conf_r_sum = 0.0;
      int high_conf_wins = 0;
      int low_conf_wins = 0;

      double high_qual_r_sum = 0.0;
      double low_qual_r_sum = 0.0;
      int high_qual_wins = 0;
      int low_qual_wins = 0;

      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         if(t.paper_trade_id == 0 || !t.candidate_only)
            continue;

         // Confidence partition at 0.70
         if(t.strategy_confidence >= 0.70)
         {
            analysis.high_confidence_trades++;
            high_conf_r_sum += t.realized_r;
            if(t.net_pnl > 0.0001) high_conf_wins++;
         }
         else
         {
            analysis.low_confidence_trades++;
            low_conf_r_sum += t.realized_r;
            if(t.net_pnl > 0.0001) low_conf_wins++;
         }

         // Quality partition at 0.70
         if(t.strategy_quality >= 0.70)
         {
            analysis.high_quality_trades++;
            high_qual_r_sum += t.realized_r;
            if(t.net_pnl > 0.0001) high_qual_wins++;
         }
         else
         {
            analysis.low_quality_trades++;
            low_qual_r_sum += t.realized_r;
            if(t.net_pnl > 0.0001) low_qual_wins++;
         }
      }

      if(analysis.high_confidence_trades > 0)
      {
         analysis.high_confidence_win_rate = NormalizeDouble(((double)high_conf_wins / (double)analysis.high_confidence_trades) * 100.0, 2);
         analysis.high_confidence_avg_r    = NormalizeDouble(high_conf_r_sum / (double)analysis.high_confidence_trades, 3);
      }
      if(analysis.low_confidence_trades > 0)
      {
         analysis.low_confidence_win_rate = NormalizeDouble(((double)low_conf_wins / (double)analysis.low_confidence_trades) * 100.0, 2);
         analysis.low_confidence_avg_r    = NormalizeDouble(low_conf_r_sum / (double)analysis.low_confidence_trades, 3);
      }

      if(analysis.high_quality_trades > 0)
      {
         analysis.high_quality_win_rate = NormalizeDouble(((double)high_qual_wins / (double)analysis.high_quality_trades) * 100.0, 2);
         analysis.high_quality_avg_r    = NormalizeDouble(high_qual_r_sum / (double)analysis.high_quality_trades, 3);
      }
      if(analysis.low_quality_trades > 0)
      {
         analysis.low_quality_win_rate = NormalizeDouble(((double)low_qual_wins / (double)analysis.low_quality_trades) * 100.0, 2);
         analysis.low_quality_avg_r    = NormalizeDouble(low_qual_r_sum / (double)analysis.low_quality_trades, 3);
      }

      analysis.explanation = StringFormat("HighConf(>=0.70): %d trades, WinRate=%.1f%%, AvgR=%.2f | LowConf(<0.70): %d trades, WinRate=%.1f%%, AvgR=%.2f",
         analysis.high_confidence_trades, analysis.high_confidence_win_rate, analysis.high_confidence_avg_r,
         analysis.low_confidence_trades, analysis.low_confidence_win_rate, analysis.low_confidence_avg_r);
   }

   //+----------------------------------------------------------------+
   //| Step 10: Chronological Out-of-Sample Partitioning              |
   //| Train (50%), Validation (25%), Out-of-Sample (25%)             |
   //+----------------------------------------------------------------+
   void EvaluateOutOfSample(const SPaperTrade &trades[], SOutOfSampleResult &oos)
   {
      oos.Reset();
      int total = ArraySize(trades);
      if(total < 20)
      {
         oos.status = "INSUFFICIENT_DATA (< 20 trades)";
         return;
      }

      int train_end = total / 2;                // 50%
      int val_end   = train_end + (total / 4);  // Next 25%

      oos.train_count = train_end;
      oos.val_count   = val_end - train_end;
      oos.oos_count   = total - val_end;

      double train_r_sum = 0.0; int train_wins = 0;
      double val_r_sum   = 0.0; int val_wins   = 0;
      double oos_r_sum   = 0.0; int oos_wins   = 0;

      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         if(i < train_end)
         {
            train_r_sum += t.realized_r;
            if(t.net_pnl > 0.0001) train_wins++;
         }
         else if(i < val_end)
         {
            val_r_sum += t.realized_r;
            if(t.net_pnl > 0.0001) val_wins++;
         }
         else
         {
            oos_r_sum += t.realized_r;
            if(t.net_pnl > 0.0001) oos_wins++;
         }
      }

      if(oos.train_count > 0)
      {
         oos.train_win_rate   = NormalizeDouble(((double)train_wins / (double)oos.train_count) * 100.0, 2);
         oos.train_avg_r      = NormalizeDouble(train_r_sum / (double)oos.train_count, 3);
         oos.train_expectancy = oos.train_avg_r;
      }

      if(oos.val_count > 0)
      {
         oos.val_win_rate   = NormalizeDouble(((double)val_wins / (double)oos.val_count) * 100.0, 2);
         oos.val_avg_r      = NormalizeDouble(val_r_sum / (double)oos.val_count, 3);
         oos.val_expectancy = oos.val_avg_r;
      }

      if(oos.oos_count > 0)
      {
         oos.oos_win_rate   = NormalizeDouble(((double)oos_wins / (double)oos.oos_count) * 100.0, 2);
         oos.oos_avg_r      = NormalizeDouble(oos_r_sum / (double)oos.oos_count, 3);
         oos.oos_expectancy = oos.oos_avg_r;

         if(MathAbs(oos.train_expectancy) > 0.0001)
         {
            oos.oos_degradation_pct = NormalizeDouble(((oos.oos_expectancy - oos.train_expectancy) / MathAbs(oos.train_expectancy)) * 100.0, 2);
         }
      }

      oos.status = "SPLIT_VALID";
   }

   //+----------------------------------------------------------------+
   //| Step 11: Walk-Forward Sequential Multi-Window Analysis         |
   //+----------------------------------------------------------------+
   void EvaluateWalkForward(const SPaperTrade &trades[], SWalkForwardResult &wf)
   {
      wf.Reset();
      int total = ArraySize(trades);
      if(total < 40)
      {
         wf.status  = "INSUFFICIENT_DATA";
         wf.summary = "INSUFFICIENT_DATA (< 40 trades)";
         return;
      }

      // 4 rolling windows
      int window_size = total / 4;
      wf.windows_tested = 4;
      double is_exp_sum = 0.0;
      double oos_exp_sum = 0.0;

      for(int w = 0; w < 4; w++)
      {
         int start = w * window_size;
         int mid   = start + (window_size / 2);
         int end   = (w == 3) ? total : (w + 1) * window_size;

         double is_r = 0.0; int is_cnt = mid - start;
         double os_r = 0.0; int os_cnt = end - mid;

         for(int i = start; i < mid; i++) is_r += trades[i].realized_r;
         for(int i = mid; i < end; i++)   os_r += trades[i].realized_r;

         double is_exp = (is_cnt > 0) ? (is_r / is_cnt) : 0.0;
         double os_exp = (os_cnt > 0) ? (os_r / os_cnt) : 0.0;

         is_exp_sum  += is_exp;
         oos_exp_sum += os_exp;
         if(os_exp > 0.0) wf.windows_positive++;
      }

      double avg_is  = is_exp_sum / 4.0;
      double avg_oos = oos_exp_sum / 4.0;
      wf.walk_forward_efficiency = (MathAbs(avg_is) > 0.0001) ? NormalizeDouble(avg_oos / avg_is, 2) : 0.0;
      wf.status  = "WALK_FORWARD_VALID";
      wf.summary = StringFormat("Tested %d windows: %d positive | WFE=%.2f", wf.windows_tested, wf.windows_positive, wf.walk_forward_efficiency);
   }

   //+----------------------------------------------------------------+
   //| Step 12: Monte Carlo Bootstrap Resampling of Realized R        |
   //+----------------------------------------------------------------+
   void RunMonteCarloResampling(const SPaperTrade &trades[], int simulations, SMonteCarloResult &mc, double initial_equity = 1000.0)
   {
      mc.Reset();
      int total = ArraySize(trades);
      if(total < 10)
      {
         mc.status = "INSUFFICIENT_DATA";
         return;
      }

      mc.simulations_count = simulations;
      double sim_drawdowns[];
      int    sim_streaks[];
      ArrayResize(sim_drawdowns, simulations);
      ArrayResize(sim_streaks, simulations);

      int dd_exceed_10_count = 0;
      int dd_exceed_20_count = 0;
      double max_observed = 0.0;

      // Extract observed R multiples
      double observed_r[];
      ArrayResize(observed_r, total);
      for(int i = 0; i < total; i++)
         observed_r[i] = trades[i].realized_r;

      for(int s = 0; s < simulations; s++)
      {
         double eq = initial_equity;
         double peak = initial_equity;
         double max_dd_pct = 0.0;
         int cur_loss_streak = 0;
         int max_loss_streak = 0;

         for(int step = 0; step < total; step++)
         {
            int rand_idx = (int)(((double)MathRand() / 32768.0) * (double)total);
            if(rand_idx >= total) rand_idx = total - 1;
            double r = observed_r[rand_idx];

            // 1% risk per trade in money = $10 on $1000 baseline
            double trade_pnl = r * (0.01 * eq);
            eq += trade_pnl;

            if(eq > peak) peak = eq;
            double dd = peak - eq;
            double dd_pct = (peak > 0.0) ? (dd / peak) * 100.0 : 0.0;
            if(dd_pct > max_dd_pct) max_dd_pct = dd_pct;

            if(r < -0.0001)
            {
               cur_loss_streak++;
               if(cur_loss_streak > max_loss_streak) max_loss_streak = cur_loss_streak;
            }
            else
            {
               cur_loss_streak = 0;
            }
         }

         sim_drawdowns[s] = max_dd_pct;
         sim_streaks[s]   = max_loss_streak;

         if(max_dd_pct > max_observed) max_observed = max_dd_pct;
         if(max_dd_pct >= 10.0) dd_exceed_10_count++;
         if(max_dd_pct >= 20.0) dd_exceed_20_count++;
      }

      ArraySort(sim_drawdowns);

      mc.median_drawdown               = NormalizeDouble(GetPercentile(sim_drawdowns, 0.50), 2);
      mc.p95_drawdown                  = NormalizeDouble(GetPercentile(sim_drawdowns, 0.95), 2);
      mc.max_drawdown_observed         = NormalizeDouble(max_observed, 2);
      mc.prob_drawdown_exceeding_10pct = NormalizeDouble(((double)dd_exceed_10_count / (double)simulations) * 100.0, 2);
      mc.prob_drawdown_exceeding_20pct = NormalizeDouble(((double)dd_exceed_20_count / (double)simulations) * 100.0, 2);

      // Streaks median and P95
      double streak_doubles[];
      ArrayResize(streak_doubles, simulations);
      for(int s = 0; s < simulations; s++) streak_doubles[s] = (double)sim_streaks[s];
      ArraySort(streak_doubles);
      mc.median_consecutive_losses = (int)GetPercentile(streak_doubles, 0.50);
      mc.p95_consecutive_losses    = (int)GetPercentile(streak_doubles, 0.95);

      mc.status = "SIMULATED_BOOTSTRAP";
   }

   //+----------------------------------------------------------------+
   //| Step 13: Robustness & Sensitivity Stress Checks                |
   //+----------------------------------------------------------------+
   void RunRobustnessChecks(const SPaperTrade &trades[], SRobustnessResult &rob)
   {
      rob.Reset();
      int total = ArraySize(trades);
      if(total < 10)
      {
         rob.edge_survival_status = "INSUFFICIENT_DATA";
         return;
      }

      double base_r_sum = 0.0;
      double slip_r_sum = 0.0;
      double spread_r_sum = 0.0;
      double same_bar_worst_r_sum = 0.0;

      for(int i = 0; i < total; i++)
      {
         SPaperTrade t = trades[i];
         double r = t.realized_r;
         base_r_sum += r;
         slip_r_sum += (r - 0.05);   // -0.05R slippage penalty
         spread_r_sum += (r - 0.10); // -0.05R slippage - 0.05R spread penalty

         // Worst-case same bar ambiguity: if exit was TP on same bar, assume SL (-1.0R)
         if(t.exit_reason == EXIT_REASON_TP && t.holding_duration_sec < 900)
            same_bar_worst_r_sum += -1.0;
         else
            same_bar_worst_r_sum += r;
      }

      rob.baseline_expectancy            = NormalizeDouble(base_r_sum / (double)total, 3);
      rob.adverse_slippage_expectancy    = NormalizeDouble(slip_r_sum / (double)total, 3);
      rob.wider_spread_expectancy        = NormalizeDouble(spread_r_sum / (double)total, 3);
      rob.same_bar_worst_case_expectancy = NormalizeDouble(same_bar_worst_r_sum / (double)total, 3);

      if(rob.adverse_slippage_expectancy > 0.15 && rob.wider_spread_expectancy > 0.05)
         rob.edge_survival_status = "ROBUST_SURVIVAL";
      else if(rob.adverse_slippage_expectancy > 0.0)
         rob.edge_survival_status = "MARGINAL_EDGE";
      else
         rob.edge_survival_status = "EDGE_ERODED";
   }

   //+----------------------------------------------------------------+
   //| Step 14: Evidence Classification Verdict                       |
   //+----------------------------------------------------------------+
   ENUM_EVIDENCE_CLASSIFICATION ClassifyEvidence(const SPhase8EvaluationResult &result)
   {
      if(result.dataset_report.status == DATASET_STATUS_CORRUPTED || result.total_trades < 15)
         return EVIDENCE_INSUFFICIENT_SAMPLE;

      if(result.sample_tier == SAMPLE_PRELIMINARY)
      {
         if(result.expectancy > 0.0 && result.profit_factor > 1.0)
            return EVIDENCE_PRELIMINARY_EVIDENCE;
         return EVIDENCE_NO_EVIDENCE;
      }

      // Adequate sample (>= 30 trades)
      if(result.expectancy <= 0.0 || result.profit_factor < 1.0)
         return EVIDENCE_NO_EVIDENCE;

      if(result.oos_result.oos_expectancy > 0.0 &&
         result.robustness_result.adverse_slippage_expectancy > 0.0 &&
         result.monte_carlo_result.p95_drawdown < 20.0)
      {
         return EVIDENCE_ROBUST_PAPER_EVIDENCE;
      }

      return EVIDENCE_PROMISING_BUT_UNCONFIRMED;
   }

   //+----------------------------------------------------------------+
   //| Step 15: Run Full Comprehensive Evaluation                     |
   //+----------------------------------------------------------------+
   bool RunFullEvaluation(const SPaperTrade &trades[], SPhase8EvaluationResult &result,
                          double initial_equity = 1000.0, int mc_sims = 500)
   {
      result.Reset();
      result.generated_time = TimeCurrent();

      // 1. Dataset integrity
      ValidateDataset(trades, result.dataset_report);

      // 2. Core performance & distributions
      EvaluateOverallPerformance(trades, result, initial_equity);

      // 3. Categorical breakdowns
      EvaluateSymbols(trades, result.symbol_evaluations);
      EvaluateRegimes(trades, result.regime_evaluations);
      EvaluateDirections(trades, result.direction_evaluations);

      // 4. Detailed layers
      EvaluateEquityCurve(trades, initial_equity, result.equity_analysis);
      ValidateRiskContract(trades, result.risk_report);
      AnalyzeTradeQuality(trades, result.quality_analysis);
      EvaluateOutOfSample(trades, result.oos_result);
      EvaluateWalkForward(trades, result.walk_forward_result);
      RunMonteCarloResampling(trades, mc_sims, result.monte_carlo_result, initial_equity);
      RunRobustnessChecks(trades, result.robustness_result);

      // 5. Final evidence classification
      result.evidence_class = ClassifyEvidence(result);
      m_last_result = result;

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "StatisticalEvaluation", "EVALUATION_COMPLETE",
            StringFormat("Phase 8 Evaluation Complete: Trades=%d | WinRate=%.1f%% | PF=%.2f | AvgR=%.2f | Evidence=%s",
               result.total_trades, result.win_rate, result.profit_factor, result.avg_r,
               EvidenceClassificationToString(result.evidence_class)));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Step 16: Format Comprehensive Evaluation Report String         |
   //+----------------------------------------------------------------+
      int  GetTotalTrades() const { return m_last_result.total_trades; }
   string GenerateEvaluationReport() { return GenerateFullEvaluationReport(m_last_result); }
   void GetLastResult(SPhase8EvaluationResult &out) const { out = m_last_result; }

   string GenerateFullEvaluationReport(const SPhase8EvaluationResult &r)
   {
      string out = "";
      out += "\n======================================================================\n";
      out += "       ATG TRADING ENGINE - PHASE 8 STATISTICAL EVALUATION REPORT     \n";
      out += "======================================================================\n";
      out += StringFormat("Strategy:              %s\n", r.strategy_name);
      out += StringFormat("Dataset Status:        %s\n", DatasetStatusToString(r.dataset_report.status));
      out += StringFormat("Total Trades Audited:  %d (Valid: %d, Rejected: %d)\n",
         r.dataset_report.total_records, r.dataset_report.valid_records, r.dataset_report.rejected_records);
      out += StringFormat("Sample Classification: %s\n", SampleClassificationToString(r.sample_tier));
      out += StringFormat("Evidence Verdict:      %s\n", EvidenceClassificationToString(r.evidence_class));
      out += "----------------------------------------------------------------------\n";
      out += "1. OVERALL CORE PERFORMANCE\n";
      out += StringFormat("  Trades:       %d (Wins: %d, Losses: %d, BE: %d)\n",
         r.total_trades, r.winning_trades, r.losing_trades, r.breakeven_trades);
      out += StringFormat("  Win Rate:     %.2f%%  |  Loss Rate: %.2f%%\n", r.win_rate, r.loss_rate);
      out += StringFormat("  Gross Profit: $%.2f  |  Gross Loss: $%.2f\n", r.gross_profit, r.gross_loss);
      out += StringFormat("  Net PnL:      $%.2f  |  Profit Factor: %.2f\n", r.net_pnl, r.profit_factor);
      out += StringFormat("  Avg Win:      $%.2f  |  Avg Loss: $%.2f\n", r.avg_win, r.avg_loss);
      out += StringFormat("  Avg Realized R: %.3fR |  Median R: %.3fR\n", r.avg_r, r.median_r);
      out += StringFormat("  Expectancy:   %.3fR per trade\n", r.expectancy);
      out += StringFormat("  Max Drawdown: $%.2f (%.2f%%)\n", r.max_drawdown, r.max_drawdown_pct);
      out += StringFormat("  Streaks:      Max Win Streak: %d | Max Loss Streak: %d\n", r.max_win_streak, r.max_loss_streak);
      out += StringFormat("  Duration:     Avg: %d sec | Longest: %d sec\n", r.avg_duration_sec, r.longest_duration_sec);
      out += "----------------------------------------------------------------------\n";
      out += "2. STATISTICAL DISTRIBUTIONS & DISPERSION\n";
      out += StringFormat("  Realized R:   Mean=%.2fR, Median=%.2fR, SD=%.2f, P10=%.2f, P25=%.2f, P75=%.2f, P90=%.2f\n",
         r.r_distribution.mean, r.r_distribution.median, r.r_distribution.std_dev,
         r.r_distribution.p10, r.r_distribution.p25, r.r_distribution.p75, r.r_distribution.p90);
      out += StringFormat("  Net PnL ($):  Mean=$%.2f, Median=$%.2f, SD=$%.2f, Min=$%.2f, Max=$%.2f\n",
         r.pnl_distribution.mean, r.pnl_distribution.median, r.pnl_distribution.std_dev,
         r.pnl_distribution.min_val, r.pnl_distribution.max_val);
      out += "----------------------------------------------------------------------\n";
      out += "3. CATEGORICAL BREAKDOWNS\n";
      out += "  Directional:\n";
      out += StringFormat("    BUY:  Trades=%d, WinRate=%.1f%%, NetPnL=$%.2f, AvgR=%.2fR, PF=%.2f\n",
         r.direction_evaluations[0].trades, r.direction_evaluations[0].win_rate,
         r.direction_evaluations[0].net_pnl, r.direction_evaluations[0].avg_r, r.direction_evaluations[0].profit_factor);
      out += StringFormat("    SELL: Trades=%d, WinRate=%.1f%%, NetPnL=$%.2f, AvgR=%.2fR, PF=%.2f\n",
         r.direction_evaluations[1].trades, r.direction_evaluations[1].win_rate,
         r.direction_evaluations[1].net_pnl, r.direction_evaluations[1].avg_r, r.direction_evaluations[1].profit_factor);
      out += "  Symbols:\n";
      for(int s = 0; s < ArraySize(r.symbol_evaluations); s++)
      {
         SSymbolEvaluation se = r.symbol_evaluations[s];
         out += StringFormat("    %-8s: Trades=%2d, WinRate=%5.1f%%, NetPnL=$%7.2f, PF=%5.2f, Tier=%s\n",
            se.symbol, se.sample_size, se.win_rate, se.net_pnl, se.profit_factor, SampleClassificationToString(se.sample_tier));
      }
      out += "  Regimes:\n";
      for(int rg = 0; rg < ArraySize(r.regime_evaluations); rg++)
      {
         SRegimeEvaluation re = r.regime_evaluations[rg];
         out += StringFormat("    %-24s: Trades=%2d, WinRate=%5.1f%%, NetPnL=$%7.2f, Buys=%d, Sells=%d\n",
            re.regime_name, re.trades, re.win_rate, re.net_pnl, re.buy_count, re.sell_count);
      }
      out += "----------------------------------------------------------------------\n";
      out += "4. RISK CONTRACT AUDIT & TRADE QUALITY\n";
      out += StringFormat("  Audited Trades: %d | Violations: %d | Status: %s\n",
         r.risk_report.total_audited, r.risk_report.violations_count, (r.risk_report.violations_count == 0 ? "PASSED" : "VIOLATIONS_FOUND"));
      out += StringFormat("  Quality Correlation: %s\n", r.quality_analysis.explanation);
      out += "----------------------------------------------------------------------\n";
      out += "5. OUT-OF-SAMPLE & WALK-FORWARD ROBUSTNESS\n";
      out += StringFormat("  Out-of-Sample:  Status=%s | TrainExp=%.2fR, ValExp=%.2fR, OOSExp=%.2fR | Degradation=%.1f%%\n",
         r.oos_result.status, r.oos_result.train_expectancy, r.oos_result.val_expectancy,
         r.oos_result.oos_expectancy, r.oos_result.oos_degradation_pct);
      out += StringFormat("  Walk-Forward:   Status=%s | %s\n", r.walk_forward_result.status, r.walk_forward_result.summary);
      out += "----------------------------------------------------------------------\n";
      out += "6. MONTE CARLO & STRESS RESILIENCE\n";
      out += StringFormat("  Monte Carlo:    Status=%s (%d runs) | MedianDD=%.1f%%, P95_DD=%.1f%%, P(DD>10%%)=%.1f%%, P(DD>20%%)=%.1f%%\n",
         r.monte_carlo_result.status, r.monte_carlo_result.simulations_count,
         r.monte_carlo_result.median_drawdown, r.monte_carlo_result.p95_drawdown,
         r.monte_carlo_result.prob_drawdown_exceeding_10pct, r.monte_carlo_result.prob_drawdown_exceeding_20pct);
      out += StringFormat("  Stress Checks:  EdgeStatus=%s | Baseline=%.2fR, AdverseSlip=%.2fR, WideSpread=%.2fR\n",
         r.robustness_result.edge_survival_status, r.robustness_result.baseline_expectancy,
         r.robustness_result.adverse_slippage_expectancy, r.robustness_result.wider_spread_expectancy);
      out += "----------------------------------------------------------------------\n";
      out += "7. SIMULATION BOUNDARIES & CAVEATS\n";
      out += "  " + r.limitations_summary + "\n";
      out += "  Safety: can_trade = FALSE, MONITOR_ONLY = TRUE, Zero Live Execution.\n";
      out += "======================================================================\n";
      return out;
   }
};

#endif
