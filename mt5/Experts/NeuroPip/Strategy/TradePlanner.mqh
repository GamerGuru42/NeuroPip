//+------------------------------------------------------------------+
//| TradePlanner.mqh                                                 |
//| NeuroPip - Phase 5                                      |
//| Trade Planning Engine                                             |
//| Converts approved Phase 4 Strategy Candidates into structured,   |
//| explainable Trade Plans using existing RiskEngine & PositionSizer.|
//|                                                                  |
//| MONITOR_ONLY - No execution capability                            |
//| This module NEVER sends an order.                                |
//+------------------------------------------------------------------+
#ifndef ATG_TRADE_PLANNER_MQH
#define ATG_TRADE_PLANNER_MQH

#include "TradePlanTypes.mqh"
#include "StrategyTypes.mqh"
#include "StrategyDecisionEngine.mqh"
#include "SpreadPolicy.mqh"
#include "../Intelligence/MarketFeatureTypes.mqh"
#include "../Intelligence/MarketIntelligenceEngine.mqh"
#include "../Execution/RiskEngine.mqh"
#include "../Execution/PositionSizer.mqh"
#include "../MarketData/SymbolUniverseManager.mqh"
#include "../MarketData/MarketStateCache.mqh"
#include "../Analytics/ForwardEvidenceEngine.mqh"
#include "../Diagnostics/Logger.mqh"

//+------------------------------------------------------------------+
//| Per-symbol trade plan state                                       |
//+------------------------------------------------------------------+
struct SSymbolPlanState
{
   string                 symbol;
   STradePlan             latest_plan;
   datetime               last_plan_bar_time;
   ENUM_TRADE_PLAN_STATUS last_logged_status;
};

//+------------------------------------------------------------------+
//| Trade Planner Configuration                                       |
//+------------------------------------------------------------------+
struct STradePlannerConfig
{
   double   risk_percent;             // Account risk percent per trade (e.g. 1.0)
   double   sl_atr_multiplier;        // ATR multiplier for stop loss (e.g. 2.0)
   double   tp_rr_multiplier;         // Reward:Risk multiplier for TP (e.g. 2.0)
   double   min_reward_risk;          // Minimum R:R ratio required (e.g. 1.5)
   int      plan_expiry_sec;          // Seconds before plan expires (e.g. 1800)
   int      max_spread_tolerance;     // Maximum spread in points allowed (e.g. 40)
   double   entry_buffer_points;      // Buffer points for entry if needed (e.g. 0.0)

   void Reset()
   {
      risk_percent         = 1.0;
      sl_atr_multiplier    = 2.0;
      tp_rr_multiplier     = 2.0;
      min_reward_risk      = 1.5;
      plan_expiry_sec      = 1800;   // 30 minutes
      max_spread_tolerance = 40;     // 40 points
      entry_buffer_points  = 0.0;
   }
};

//+------------------------------------------------------------------+
//| CTradePlanner                                                    |
//+------------------------------------------------------------------+
class CTradePlanner
{
private:
   CLogger*                    m_logger;
   CRiskEngine*                m_risk_engine;
   CPositionSizer*             m_position_sizer;
   CMarketIntelligenceEngine*  m_intelligence;
   CSymbolUniverseManager*     m_universe;
   CMarketStateCache*          m_market_cache;
   CForwardEvidenceEngine*     m_evidence;

   STradePlannerConfig         m_config;
   SSymbolPlanState            m_states[];
   ulong                       m_plan_counter;

   //+----------------------------------------------------------------+
   //| Find slot for symbol                                           |
   //+----------------------------------------------------------------+
   int FindSlot(const string symbol)
   {
      for(int i = 0; i < ArraySize(m_states); i++)
      {
         if(m_states[i].symbol == symbol)
            return i;
      }
      return -1;
   }

   //+----------------------------------------------------------------+
   //| Ensure slot exists for symbol                                  |
   //+----------------------------------------------------------------+
   int EnsureSlot(const string symbol)
   {
      int idx = FindSlot(symbol);
      if(idx >= 0)
         return idx;

      int size = ArraySize(m_states);
      ArrayResize(m_states, size + 1);
      m_states[size].symbol              = symbol;
      m_states[size].last_plan_bar_time  = 0;
      m_states[size].last_logged_status  = TRADE_PLAN_PENDING;
      m_states[size].latest_plan.Reset();

      return size;
   }

   //+----------------------------------------------------------------+
   //| Convert signal direction to trade direction                    |
   //+----------------------------------------------------------------+
   ENUM_ATG_TRADE_DIRECTION SignalToTradeDirection(ENUM_ATG_SIGNAL_DIRECTION sig_dir)
   {
      if(sig_dir == SIGNAL_DIR_BUY)  return ATG_DIRECTION_BUY;
      if(sig_dir == SIGNAL_DIR_SELL) return ATG_DIRECTION_SELL;
      return ATG_DIRECTION_NONE;
   }

   //+----------------------------------------------------------------+
   //| Build formatted plan explanation                               |
   //+----------------------------------------------------------------+
   void FormatPlan(STradePlan &plan)
   {
      string exp = "\n==================================================\n";
      exp += StringFormat("ATG_TRADE_PLAN #%I64u [%s]\n", plan.plan_id, plan.StatusToString());
      exp += "==================================================\n";
      exp += StringFormat("Symbol:              %s\n", plan.symbol);
      exp += StringFormat("Strategy:            %s (v%s)\n", plan.strategy_id, plan.strategy_version);
      exp += StringFormat("Decision ID:         %I64u\n", plan.source_decision_id);
      exp += StringFormat("Direction:           %s\n", plan.DirectionToString());
      exp += StringFormat("Primary Timeframe:   %s\n", EnumToString(plan.primary_timeframe));
      exp += StringFormat("Source Bar Time:     %s\n", TimeToString(plan.source_bar_time, TIME_DATE|TIME_SECONDS));
      exp += StringFormat("Creation Time:       %s\n", TimeToString(plan.creation_time, TIME_DATE|TIME_SECONDS));
      exp += StringFormat("Expiration Time:     %s\n", TimeToString(plan.expiration_time, TIME_DATE|TIME_SECONDS));
      exp += StringFormat("Strategy Confidence: %.2f\n", plan.strategy_confidence);
      exp += StringFormat("Strategy Quality:    %.2f\n", plan.strategy_quality);
      exp += StringFormat("Market Regime:       %s\n", EnumToString(plan.regime));

      int digits = (int)SymbolInfoInteger(plan.symbol, SYMBOL_DIGITS);
      if(digits <= 0) digits = 5;

      exp += "\n--- PRICE LEVELS ---\n";
      exp += StringFormat("Entry Price:         %.*f\n", digits, plan.entry_price);
      exp += StringFormat("Stop Loss:           %.*f  (%.1f pts, %s)\n",
         digits, plan.stop_loss, plan.risk_distance_points, plan.levels.sl_method);
      exp += StringFormat("Take Profit:         %.*f  (%.1f pts, %s)\n",
         digits, plan.take_profit, plan.reward_distance_points, plan.levels.tp_method);
      if(plan.invalidation_price > 0.0)
      {
         exp += StringFormat("Invalidation Level:  %.*f\n", digits, plan.invalidation_price);
      }
      exp += StringFormat("Risk Distance:       %.*f price / %.1f points\n",
         digits, plan.risk_distance_price, plan.risk_distance_points);
      exp += StringFormat("Reward Distance:     %.*f price / %.1f points\n",
         digits, plan.reward_distance_price, plan.reward_distance_points);
      exp += StringFormat("Risk/Reward Ratio:   %.2f (Configured Min: %.2f)\n",
         plan.risk_reward_ratio, plan.min_reward_risk);

      exp += "\n--- RISK & POSITION SIZING ---\n";
      exp += StringFormat("Account Equity:      $%.2f\n", plan.account_equity);
      exp += StringFormat("Risk Percentage:     %.2f%%\n", plan.risk_percent);
      exp += StringFormat("Risk Budget (Money): $%.2f\n", plan.risk_money);
      exp += StringFormat("Calculated Volume:   %.8f\n", plan.calculated_volume);
      exp += StringFormat("Normalized Volume:   %.4f (Min: %.4f, Max: %.4f, Step: %.4f)\n",
         plan.normalized_volume, plan.volume_min, plan.volume_max, plan.volume_step);
      exp += StringFormat("Expected Loss:       $%.2f\n", plan.expected_loss);
      exp += StringFormat("Expected Reward:     $%.2f\n", plan.expected_reward);

      exp += "\n--- BROKER CONSTRAINTS ---\n";
      exp += StringFormat("Spread at Planning:  %d points (Max Allowed: %d)\n",
         plan.spread_at_planning, m_config.max_spread_tolerance);
      exp += StringFormat("Broker Stops Level:  %d points\n", plan.stops_level);
      exp += StringFormat("Broker Freeze Level: %d points\n", plan.freeze_level);
      exp += StringFormat("Point Size:          %.8f\n", plan.point_size);
      exp += StringFormat("Tick Size:           %.8f\n", plan.tick_size);
      exp += StringFormat("Tick Value:          %.8f\n", plan.tick_value);

      exp += "\n--- VALIDATION & SAFETY GATES ---\n";
      exp += StringFormat("Validation Flags:    0x%04X\n", plan.validation_flags);
      if(plan.plan_status == TRADE_PLAN_VALID)
      {
         exp += "Validation Status:   ALL 14 GATES PASSED (VALID)\n";
         exp += "Reason:\n";
         exp += " - Approved Phase 4 strategy candidate qualified\n";
         exp += " - Market data and ATR volatility verified\n";
         exp += " - Direction and price boundaries logical\n";
         exp += " - Structural invalidation protection satisfied\n";
         exp += " - R:R requirement satisfied\n";
         exp += " - Spread within tolerance\n";
         exp += " - Broker stops/freeze levels respected\n";
         exp += " - Risk budget calculated and compliant\n";
         exp += " - Volume sized and broker normalized\n";
      }
      else
      {
         exp += StringFormat("Validation Status:   REJECTED [%s]\n", plan.RejectionToString());
         exp += StringFormat("Rejection Detail:    %s\n", plan.rejection_detail);
      }

      exp += "\n--- EXECUTION BOUNDARY ---\n";
      exp += "Execution Authorization: DISABLED — CANDIDATE ONLY (DRY-RUN)\n";
      exp += "Live Order Submission:   BLOCKED (can_trade=false, MONITOR_ONLY=true)\n";
      exp += "==================================================\n";

      plan.formatted_plan = exp;
   }

public:
   CTradePlanner(CLogger* logger,
                 CRiskEngine* risk_engine,
                 CPositionSizer* position_sizer,
                 CMarketIntelligenceEngine* intelligence,
                 CSymbolUniverseManager* universe,
                 CMarketStateCache* market_cache)
      : m_logger(logger),
        m_risk_engine(risk_engine),
        m_position_sizer(position_sizer),
        m_intelligence(intelligence),
        m_universe(universe),
        m_market_cache(market_cache),
        m_evidence(NULL),
        m_plan_counter(5000000)
   {
      m_config.Reset();
   }

   // Configuration access
   STradePlannerConfig GetConfig() const { return m_config; }
   void SetConfig(const STradePlannerConfig &cfg) { m_config = cfg; }
   void SetForwardEvidenceEngine(CForwardEvidenceEngine* evidence) { m_evidence = evidence; }

   //+----------------------------------------------------------------+
   //| Initialize planner for universe                                |
   //+----------------------------------------------------------------+
   bool Initialize()
   {
      int count = m_universe.GetSymbolCount();
      ArrayResize(m_states, 0);

      for(int i = 0; i < count; i++)
      {
         string sym = m_universe.GetBrokerSymbol(i);
         if(sym != "")
            EnsureSlot(sym);
      }

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "TradePlanner", "INIT_SUCCESS",
            StringFormat("Trade Planner initialized for %d symbols. SL=ATR×%.1f, TP=RR×%.1f, MinRR=%.2f, Risk=%.1f%%",
               ArraySize(m_states),
               m_config.sl_atr_multiplier,
               m_config.tp_rr_multiplier,
               m_config.min_reward_risk,
               m_config.risk_percent));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Build a Trade Plan from an approved Strategy Decision           |
   //| Enforces all 14 Section 11 Validation Gates.                   |
   //| Returns true if plan is completely valid (DRY-RUN ONLY).       |
   //+----------------------------------------------------------------+
   bool BuildPlan(const SStrategyDecision &decision,
                  STradePlan &out_plan)
   {
      out_plan.Reset();
      m_plan_counter++;

      // Populate identity & strategy context
      out_plan.plan_id              = m_plan_counter;
      out_plan.symbol               = decision.symbol;
      out_plan.strategy_id          = decision.strategy_id;
      out_plan.strategy_version     = decision.strategy_version;
      out_plan.source_decision_id   = decision.decision_id;
      out_plan.strategy_decision_id = decision.decision_id;
      out_plan.primary_timeframe    = PERIOD_M15;
      out_plan.creation_time        = TimeCurrent();
      out_plan.created_time         = out_plan.creation_time;
      out_plan.source_bar_time      = decision.bar_time;
      out_plan.expiration_time      = out_plan.creation_time + m_config.plan_expiry_sec;
      out_plan.expiry_time          = out_plan.expiration_time;

      out_plan.strategy_confidence  = decision.confidence;
      out_plan.strategy_quality     = decision.quality_score;
      out_plan.regime               = decision.primary_regime;
      out_plan.supporting_evidence  = decision.formatted_explanation;
      out_plan.min_reward_risk      = m_config.min_reward_risk;
      out_plan.risk_percent         = (m_risk_engine != NULL) ? m_risk_engine.GetDefaultRiskPercent() : m_config.risk_percent;

      // Hard locks
      out_plan.candidate_only       = true;
      out_plan.execution_disabled   = true;
      out_plan.execution_authorized = false;
      out_plan.plan_status          = TRADE_PLAN_PENDING;
      out_plan.status               = TRADE_PLAN_PENDING;

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_DEBUG, "TradePlanner", "TRADE_PLAN_EVALUATION",
            StringFormat("Evaluating trade plan for %s [%s Decision #%I64u]",
               decision.symbol, decision.strategy_id, decision.decision_id));
      }

      //--------------------------------------------------------------
      // GATE 1: SOURCE_DECISION_VALID
      //--------------------------------------------------------------
      if(!decision.is_approved || decision.status != STRATEGY_APPROVED)
      {
         RejectPlan(out_plan, PLAN_REJECT_NO_STRATEGY, "Source strategy decision is not APPROVED.");
         return false;
      }
      out_plan.validation_flags |= PLAN_GATE_DECISION_VALID;

      //--------------------------------------------------------------
      // GATE 2: DATA_VALID
      //--------------------------------------------------------------
      if(decision.symbol == "")
      {
         RejectPlan(out_plan, PLAN_REJECT_DATA_INVALID, "Symbol name is empty.");
         return false;
      }

      double point      = SymbolInfoDouble(decision.symbol, SYMBOL_POINT);
      int digits        = (int)SymbolInfoInteger(decision.symbol, SYMBOL_DIGITS);
      double tick_size  = SymbolInfoDouble(decision.symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(decision.symbol, SYMBOL_TRADE_TICK_VALUE);

      if(point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0)
      {
         RejectPlan(out_plan, PLAN_REJECT_DATA_INVALID,
            StringFormat("Invalid broker symbol economics: point=%.8f tick_size=%.8f tick_val=%.8f",
               point, tick_size, tick_value));
         return false;
      }

      out_plan.point_size  = point;
      out_plan.tick_size   = tick_size;
      out_plan.tick_value  = tick_value;

      SMultiTimeframeFeatures mtf;
      if(m_intelligence == NULL || !m_intelligence.GetLatestFeatures(decision.symbol, mtf) || !mtf.overall_data_ready)
      {
         out_plan.plan_status = TRADE_PLAN_INSUFFICIENT_DATA;
         out_plan.status      = TRADE_PLAN_INSUFFICIENT_DATA;
         RejectPlan(out_plan, PLAN_REJECT_DATA_INVALID, "Market features unavailable or data not ready.");
         return false;
      }
      out_plan.validation_flags |= PLAN_GATE_DATA_VALID;

      //--------------------------------------------------------------
      // GATE 3: DIRECTION_VALID
      //--------------------------------------------------------------
      out_plan.direction = SignalToTradeDirection(decision.direction);
      if(out_plan.direction != ATG_DIRECTION_BUY && out_plan.direction != ATG_DIRECTION_SELL)
      {
         RejectPlan(out_plan, PLAN_REJECT_DIRECTION_INVALID, "Direction is NONE or unrecognized.");
         return false;
      }
      out_plan.validation_flags |= PLAN_GATE_DIRECTION_VALID;

      //--------------------------------------------------------------
      // GATE 4: ENTRY_VALID
      //--------------------------------------------------------------
      MqlTick tick;
      if(!SymbolInfoTick(decision.symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
      {
         RejectPlan(out_plan, PLAN_REJECT_INVALID_ENTRY, "Cannot obtain live market tick prices.");
         return false;
      }

      if(out_plan.direction == ATG_DIRECTION_BUY)
         out_plan.entry_price = NormalizeDouble(tick.ask, digits);
      else
         out_plan.entry_price = NormalizeDouble(tick.bid, digits);

      if(out_plan.entry_price <= 0.0)
      {
         RejectPlan(out_plan, PLAN_REJECT_INVALID_ENTRY, "Computed entry price is zero or negative.");
         return false;
      }
      out_plan.levels.entry_price = out_plan.entry_price;
      out_plan.validation_flags |= PLAN_GATE_ENTRY_VALID;

      //--------------------------------------------------------------
      // GATE 8: SPREAD_VALID (Checked using Centralized Asset-Class SpreadPolicy)
      //--------------------------------------------------------------
      int spread_points = (int)MathRound((tick.ask - tick.bid) / point);
      out_plan.spread_at_planning = spread_points;

      double atr_price_planning = mtf.tf_m15.volatility.atr;
      if(atr_price_planning <= 0.0) atr_price_planning = mtf.tf_m15.volatility.atr_points * point;

      string spread_gate_rej = "";
      if(!CSpreadPolicy::ValidateSpread(decision.symbol, spread_points, point, atr_price_planning, 0.0, spread_gate_rej))
      {
         RejectPlan(out_plan, PLAN_REJECT_SPREAD_EXCEEDED, spread_gate_rej);
         return false;
      }
      out_plan.validation_flags |= PLAN_GATE_SPREAD_VALID;

      //--------------------------------------------------------------
      // GATE 9: BROKER_CONSTRAINTS_VALID (Stops level, Freeze, Trade Mode)
      //--------------------------------------------------------------
      ENUM_SYMBOL_TRADE_MODE trade_mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(decision.symbol, SYMBOL_TRADE_MODE);
      if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      {
         if(m_logger != NULL) m_logger.Log(LOG_LEVEL_WARNING, "TradePlanner", "TRADE_PLAN_BROKER_REJECTED", "Symbol trading mode is disabled.");
         RejectPlan(out_plan, PLAN_REJECT_BROKER_CONSTRAINTS, "Symbol trading mode is DISABLED by broker.");
         return false;
      }

      int stops_level  = (int)SymbolInfoInteger(decision.symbol, SYMBOL_TRADE_STOPS_LEVEL);
      int freeze_level = (int)SymbolInfoInteger(decision.symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      out_plan.stops_level  = stops_level;
      out_plan.freeze_level = freeze_level;

      double vol_min  = SymbolInfoDouble(decision.symbol, SYMBOL_VOLUME_MIN);
      double vol_max  = SymbolInfoDouble(decision.symbol, SYMBOL_VOLUME_MAX);
      double vol_step = SymbolInfoDouble(decision.symbol, SYMBOL_VOLUME_STEP);
      if(vol_min <= 0.0 || vol_max < vol_min || vol_step <= 0.0)
      {
         RejectPlan(out_plan, PLAN_REJECT_BROKER_CONSTRAINTS,
            StringFormat("Invalid broker volume specifications: min=%.4f max=%.4f step=%.4f",
               vol_min, vol_max, vol_step));
         return false;
      }
      out_plan.volume_min  = vol_min;
      out_plan.volume_max  = vol_max;
      out_plan.volume_step = vol_step;
      out_plan.sizing.volume_min  = vol_min;
      out_plan.sizing.volume_max  = vol_max;
      out_plan.sizing.volume_step = vol_step;

      out_plan.validation_flags |= PLAN_GATE_BROKER_VALID;

      //--------------------------------------------------------------
      // GATE 5: SL_VALID
      //--------------------------------------------------------------
      double atr_points = mtf.tf_m15.volatility.atr_points;
      if(atr_points <= 0.0)
      {
         // Fallback to H1 ATR
         atr_points = mtf.tf_h1.volatility.atr_points;
         if(atr_points <= 0.0)
         {
            RejectPlan(out_plan, PLAN_REJECT_INVALID_STOP, "ATR volatility data is missing or zero.");
            return false;
         }
      }

      double sl_distance_pts = atr_points * m_config.sl_atr_multiplier;
      double sl_distance_price = sl_distance_pts * point;

      if(out_plan.direction == ATG_DIRECTION_BUY)
      {
         out_plan.stop_loss = NormalizeDouble(out_plan.entry_price - sl_distance_price, digits);
         out_plan.levels.sl_method = StringFormat("ATR_%.1fX", m_config.sl_atr_multiplier);

         // Validate against swing low structure
         double swing_low = mtf.tf_m15.structure.recent_swing_low;
         if(swing_low > 0.0 && swing_low < out_plan.entry_price)
         {
            out_plan.invalidation_price = swing_low;
            double swing_sl = NormalizeDouble(swing_low - (5.0 * point), digits);
            if(swing_sl > 0.0 && swing_sl < out_plan.stop_loss)
            {
               out_plan.stop_loss = swing_sl;
               out_plan.levels.sl_method = "SWING_LOW_5PT_BUFFER";
            }
         }

         // Strict direction check: BUY SL MUST be below entry
         if(out_plan.stop_loss >= out_plan.entry_price)
         {
            RejectPlan(out_plan, PLAN_REJECT_INVALID_STOP,
               StringFormat("BUY Stop Loss (%.*f) is not below entry price (%.*f).",
                  digits, out_plan.stop_loss, digits, out_plan.entry_price));
            return false;
         }
      }
      else // SELL
      {
         out_plan.stop_loss = NormalizeDouble(out_plan.entry_price + sl_distance_price, digits);
         out_plan.levels.sl_method = StringFormat("ATR_%.1fX", m_config.sl_atr_multiplier);

         // Validate against swing high structure
         double swing_high = mtf.tf_m15.structure.recent_swing_high;
         if(swing_high > 0.0 && swing_high > out_plan.entry_price)
         {
            out_plan.invalidation_price = swing_high;
            double swing_sl = NormalizeDouble(swing_high + (5.0 * point), digits);
            if(swing_sl > 0.0 && swing_sl > out_plan.stop_loss)
            {
               out_plan.stop_loss = swing_sl;
               out_plan.levels.sl_method = "SWING_HIGH_5PT_BUFFER";
            }
         }

         // Strict direction check: SELL SL MUST be above entry
         if(out_plan.stop_loss <= out_plan.entry_price)
         {
            RejectPlan(out_plan, PLAN_REJECT_INVALID_STOP,
               StringFormat("SELL Stop Loss (%.*f) is not above entry price (%.*f).",
                  digits, out_plan.stop_loss, digits, out_plan.entry_price));
            return false;
         }
      }

      out_plan.risk_distance_price  = MathAbs(out_plan.entry_price - out_plan.stop_loss);
      out_plan.risk_distance_points = NormalizeDouble(out_plan.risk_distance_price / point, 1);

      if(out_plan.risk_distance_points <= 0.0)
      {
         RejectPlan(out_plan, PLAN_REJECT_INVALID_STOP, "Stop loss distance is zero points.");
         return false;
      }

      // Check broker stops level constraint
      if(stops_level > 0 && out_plan.risk_distance_points < (double)stops_level)
      {
         if(m_logger != NULL) m_logger.Log(LOG_LEVEL_WARNING, "TradePlanner", "TRADE_PLAN_BROKER_REJECTED", "SL closer than broker stops level.");
         RejectPlan(out_plan, PLAN_REJECT_BROKER_CONSTRAINTS,
            StringFormat("SL distance (%.1f pts) is less than broker stop level (%d pts).",
               out_plan.risk_distance_points, stops_level));
         return false;
      }

      out_plan.levels.stop_loss          = out_plan.stop_loss;
      out_plan.levels.invalidation_price = out_plan.invalidation_price;
      out_plan.levels.sl_distance_price  = out_plan.risk_distance_price;
      out_plan.levels.sl_distance_points = out_plan.risk_distance_points;
      out_plan.levels.sl_atr_multiple    = (atr_points > 0.0) ? (out_plan.risk_distance_points / atr_points) : 0.0;
      out_plan.validation_flags |= PLAN_GATE_SL_VALID;

      //--------------------------------------------------------------
      // GATE 6: TP_VALID
      //--------------------------------------------------------------
      double tp_distance_pts = out_plan.risk_distance_points * m_config.tp_rr_multiplier;
      double tp_distance_price = tp_distance_pts * point;

      if(out_plan.direction == ATG_DIRECTION_BUY)
      {
         out_plan.take_profit = NormalizeDouble(out_plan.entry_price + tp_distance_price, digits);
         if(out_plan.take_profit <= out_plan.entry_price)
         {
            RejectPlan(out_plan, PLAN_REJECT_INVALID_TP,
               StringFormat("BUY Take Profit (%.*f) is not above entry (%.*f).",
                  digits, out_plan.take_profit, digits, out_plan.entry_price));
            return false;
         }
      }
      else // SELL
      {
         out_plan.take_profit = NormalizeDouble(out_plan.entry_price - tp_distance_price, digits);
         if(out_plan.take_profit >= out_plan.entry_price)
         {
            RejectPlan(out_plan, PLAN_REJECT_INVALID_TP,
               StringFormat("SELL Take Profit (%.*f) is not below entry (%.*f).",
                  digits, out_plan.take_profit, digits, out_plan.entry_price));
            return false;
         }
      }

      out_plan.reward_distance_price  = MathAbs(out_plan.take_profit - out_plan.entry_price);
      out_plan.reward_distance_points = NormalizeDouble(out_plan.reward_distance_price / point, 1);

      if(stops_level > 0 && out_plan.reward_distance_points < (double)stops_level)
      {
         if(m_logger != NULL) m_logger.Log(LOG_LEVEL_WARNING, "TradePlanner", "TRADE_PLAN_BROKER_REJECTED", "TP closer than broker stops level.");
         RejectPlan(out_plan, PLAN_REJECT_BROKER_CONSTRAINTS,
            StringFormat("TP distance (%.1f pts) is less than broker stop level (%d pts).",
               out_plan.reward_distance_points, stops_level));
         return false;
      }

      out_plan.levels.take_profit        = out_plan.take_profit;
      out_plan.levels.tp_distance_price  = out_plan.reward_distance_price;
      out_plan.levels.tp_distance_points = out_plan.reward_distance_points;
      out_plan.levels.tp_method          = StringFormat("RR_%.1fX", m_config.tp_rr_multiplier);
      out_plan.levels.tp_atr_multiple    = (atr_points > 0.0) ? (out_plan.reward_distance_points / atr_points) : 0.0;
      out_plan.levels.levels_valid       = true;
      out_plan.validation_flags |= PLAN_GATE_TP_VALID;

      //--------------------------------------------------------------
      // GATE 7: RR_VALID
      //--------------------------------------------------------------
      if(out_plan.risk_distance_points > 0.0)
         out_plan.risk_reward_ratio = out_plan.reward_distance_points / out_plan.risk_distance_points;
      else
         out_plan.risk_reward_ratio = 0.0;

      out_plan.reward_risk_ratio = out_plan.risk_reward_ratio;

      if(out_plan.risk_reward_ratio < m_config.min_reward_risk)
      {
         if(m_logger != NULL) m_logger.Log(LOG_LEVEL_WARNING, "TradePlanner", "TRADE_PLAN_RR_REJECTED",
            StringFormat("R:R ratio %.2f is below minimum %.2f", out_plan.risk_reward_ratio, m_config.min_reward_risk));
         RejectPlan(out_plan, PLAN_REJECT_NEGATIVE_RR,
            StringFormat("Risk:Reward ratio %.2f is below minimum requirement %.2f.",
               out_plan.risk_reward_ratio, m_config.min_reward_risk));
         return false;
      }
      out_plan.validation_flags |= PLAN_GATE_RR_VALID;

      //--------------------------------------------------------------
      // GATE 10: RISK_VALID (reusing existing RiskEngine)
      //--------------------------------------------------------------
      SATGRiskResult risk_result;
      if(m_risk_engine == NULL || !m_risk_engine.Calculate(decision.symbol, out_plan.entry_price, out_plan.stop_loss, out_plan.risk_percent, risk_result) || !risk_result.approved)
      {
         if(m_logger != NULL) m_logger.Log(LOG_LEVEL_WARNING, "TradePlanner", "TRADE_PLAN_RISK_REJECTED",
            StringFormat("RiskEngine rejected: %s", risk_result.reason));
         RejectPlan(out_plan, PLAN_REJECT_RISK_DENIED,
            StringFormat("RiskEngine rejected calculation: %s", risk_result.reason));
         return false;
      }

      out_plan.account_equity = risk_result.equity;
      out_plan.risk_money     = risk_result.risk_money;

      out_plan.risk.approved         = risk_result.approved;
      out_plan.risk.equity           = risk_result.equity;
      out_plan.risk.risk_percent     = risk_result.risk_percent;
      out_plan.risk.risk_money       = risk_result.risk_money;
      out_plan.risk.rejection_detail = risk_result.reason;
      out_plan.validation_flags |= PLAN_GATE_RISK_VALID;

      //--------------------------------------------------------------
      // GATE 11: POSITION_SIZE_VALID (reusing existing PositionSizer)
      //--------------------------------------------------------------
      SATGPositionSizeResult size_result;
      if(m_position_sizer == NULL || !m_position_sizer.Calculate(decision.symbol, out_plan.direction, out_plan.entry_price, out_plan.stop_loss, risk_result, size_result))
      {
         string rej_detail = StringFormat("PositionSizer failed calculation: %s", size_result.reason);
         if(m_evidence != NULL)
         {
            m_evidence.RecordPositionSizingRejection(decision.symbol, size_result.reason);
         }
         if(m_logger != NULL)
         {
            m_logger.Log(LOG_LEVEL_NOTICE, "TradePlanner", "FORWARD_PAPER_REJECTED_POSITION_SIZE",
               StringFormat("Symbol=%s Direction=%s RiskMoney=%.2f Reason=%s",
                  decision.symbol, (out_plan.direction == ATG_DIRECTION_BUY ? "BUY" : "SELL"),
                  risk_result.risk_money, size_result.reason));
         }
         RejectPlan(out_plan, PLAN_REJECT_SIZING_FAILED, rej_detail);
         return false;
      }

      out_plan.calculated_volume = size_result.raw_volume;
      out_plan.normalized_volume = size_result.normalized_volume;
      out_plan.expected_loss     = size_result.estimated_loss_at_volume;

      // Calculate expected reward from reward distance and tick economics
      if(tick_size > 0.0 && tick_value > 0.0)
      {
         double ticks = out_plan.reward_distance_price / tick_size;
         out_plan.expected_reward = NormalizeDouble(ticks * tick_value * out_plan.normalized_volume, 2);
      }
      else
      {
         out_plan.expected_reward = NormalizeDouble(out_plan.expected_loss * out_plan.risk_reward_ratio, 2);
      }

      out_plan.sizing.raw_volume       = size_result.raw_volume;
      out_plan.sizing.final_volume     = size_result.normalized_volume;
      out_plan.sizing.estimated_loss   = size_result.estimated_loss_at_volume;
      out_plan.sizing.estimated_reward = out_plan.expected_reward;
      out_plan.sizing.rejection_detail = size_result.reason;

      // Volume limits verification
      if(out_plan.normalized_volume <= 0.0 || out_plan.normalized_volume < vol_min)
      {
         string vol_rej = StringFormat("Normalized volume %.4f is below broker minimum %.4f.",
            out_plan.normalized_volume, vol_min);
         if(m_evidence != NULL)
         {
            m_evidence.RecordPositionSizingRejection(decision.symbol, vol_rej);
         }
         if(m_logger != NULL)
         {
            m_logger.Log(LOG_LEVEL_NOTICE, "TradePlanner", "FORWARD_PAPER_REJECTED_POSITION_SIZE",
               StringFormat("Symbol=%s %s", decision.symbol, vol_rej));
         }
         RejectPlan(out_plan, PLAN_REJECT_ZERO_VOLUME, vol_rej);
         return false;
      }

      if(out_plan.normalized_volume > vol_max)
      {
         RejectPlan(out_plan, PLAN_REJECT_SIZING_FAILED,
            StringFormat("Normalized volume %.4f exceeds broker maximum %.4f.",
               out_plan.normalized_volume, vol_max));
         return false;
      }
      out_plan.validation_flags |= PLAN_GATE_SIZING_VALID;

      //--------------------------------------------------------------
      // GATE 12: EXPIRATION_VALID
      //--------------------------------------------------------------
      if(TimeCurrent() > out_plan.expiration_time)
      {
         if(m_logger != NULL) m_logger.Log(LOG_LEVEL_INFO, "TradePlanner", "TRADE_PLAN_EXPIRED", "Trade plan has already expired.");
         RejectPlan(out_plan, PLAN_REJECT_EXPIRED, "Trade plan validity window expired.");
         return false;
      }
      out_plan.validation_flags |= PLAN_GATE_EXPIRY_VALID;

      //--------------------------------------------------------------
      // GATE 13: DUPLICATE_CHECK
      // (Verified in PlanForSymbol, flag set here)
      //--------------------------------------------------------------
      out_plan.validation_flags |= PLAN_GATE_DUPLICATE_CHECK;

      //--------------------------------------------------------------
      // GATE 14: EXECUTION_SAFETY_CHECK (STRICT HARD LOCK)
      //--------------------------------------------------------------
      out_plan.execution_authorized = false;   // MUST BE FALSE ALWAYS
      out_plan.candidate_only       = true;
      out_plan.execution_disabled   = true;
      out_plan.validation_flags |= PLAN_GATE_SAFETY_CHECK;

      //--------------------------------------------------------------
      // ALL GATES PASSED -> TRADE_PLAN_VALID (DRY-RUN ONLY)
      //--------------------------------------------------------------
      out_plan.plan_status = TRADE_PLAN_VALID;
      out_plan.status      = TRADE_PLAN_VALID;
      out_plan.rejection_reason = PLAN_REJECT_NONE;
      out_plan.rejection_detail = "All 14 validation gates passed successfully. Trade plan valid for dry-run.";

      FormatPlan(out_plan);

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "TradePlanner", "TRADE_PLAN_CREATED",
            StringFormat("Trade plan #%I64u created for %s", out_plan.plan_id, out_plan.symbol));
         m_logger.Log(LOG_LEVEL_INFO, "TradePlanner", "TRADE_PLAN_VALID",
            StringFormat("Plan #%I64u VALID: %s %s @ %.*f | SL=%.*f TP=%.*f | Vol=%.4f R:R=%.2f (DRY-RUN ONLY)",
               out_plan.plan_id, out_plan.symbol, out_plan.DirectionToString(),
               digits, out_plan.entry_price, digits, out_plan.stop_loss, digits, out_plan.take_profit,
               out_plan.normalized_volume, out_plan.risk_reward_ratio));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Build plan for a symbol using its latest strategy decision      |
   //| Handles duplicate suppression and lifecycle state              |
   //+----------------------------------------------------------------+
   bool PlanForSymbol(const string symbol,
                      const SStrategyDecision &decision,
                      bool force_plan = false)
   {
      if(symbol == "")
         return false;

      int slot = EnsureSlot(symbol);

      // Duplicate bar suppression: Gate 13
      datetime current_bar_time = decision.bar_time;
      if(!force_plan && current_bar_time > 0 && current_bar_time == m_states[slot].last_plan_bar_time)
      {
         if(m_logger != NULL && m_states[slot].latest_plan.plan_status == TRADE_PLAN_VALID)
         {
            m_logger.Log(LOG_LEVEL_DEBUG, "TradePlanner", "TRADE_PLAN_DUPLICATE",
               StringFormat("%s: Plan already evaluated for bar %s. Suppressing duplicate.",
                  symbol, TimeToString(current_bar_time, TIME_DATE|TIME_MINUTES)));
         }
         return (m_states[slot].latest_plan.plan_status == TRADE_PLAN_VALID);
      }

      // Check if candidate is approved
      if(!decision.is_approved || decision.status != STRATEGY_APPROVED)
      {
         if(m_states[slot].latest_plan.plan_status != TRADE_PLAN_PENDING)
         {
            m_states[slot].latest_plan.Reset();
            m_states[slot].last_logged_status = TRADE_PLAN_PENDING;
         }
         return false;
      }

      // Build the trade plan
      STradePlan plan;
      bool success = BuildPlan(decision, plan);

      m_states[slot].latest_plan        = plan;
      m_states[slot].last_plan_bar_time = current_bar_time;

      // Log status changes
      bool status_changed = (plan.plan_status != m_states[slot].last_logged_status);
      if(force_plan || status_changed || success)
      {
         m_states[slot].last_logged_status = plan.plan_status;

         if(plan.plan_status == TRADE_PLAN_VALID)
         {
            Print(plan.formatted_plan);
         }
         else if(plan.plan_status == TRADE_PLAN_REJECTED)
         {
            if(m_logger != NULL)
            {
               m_logger.Log(LOG_LEVEL_INFO, "TradePlanner", "TRADE_PLAN_REJECTED",
                  StringFormat("%s: Trade plan rejected. Reason: %s (%s)",
                     symbol, plan.RejectionToString(), plan.rejection_detail));
            }
         }
      }

      return success;
   }

   //+----------------------------------------------------------------+
   //| Process on closed-bar events                                   |
   //| Called from OnTimer when new bars close.                       |
   //| Reads latest strategy decisions and builds plans.              |
   //+----------------------------------------------------------------+
   int ProcessOnBar(CStrategyDecisionEngine &strategy_engine, bool force_all = false)
   {
      int count = m_universe.GetSymbolCount();
      int plan_count = 0;

      for(int i = 0; i < count; i++)
      {
         if(!m_universe.IsAvailable(i))
            continue;

         string symbol = m_universe.GetBrokerSymbol(i);
         if(symbol == "")
            continue;

         SStrategyDecision decision;
         if(!strategy_engine.GetLatestDecision(symbol, decision))
            continue;

         if(PlanForSymbol(symbol, decision, force_all))
            plan_count++;
      }

      return plan_count;
   }

   //+----------------------------------------------------------------+
   //| Accessor for latest plan                                       |
   //+----------------------------------------------------------------+
   bool GetLatestPlan(const string symbol, STradePlan &out_plan)
   {
      int slot = FindSlot(symbol);
      if(slot < 0) return false;
      out_plan = m_states[slot].latest_plan;
      return (out_plan.plan_id > 0);
   }

   //+----------------------------------------------------------------+
   //| Check if plan is expired                                       |
   //+----------------------------------------------------------------+
   bool CheckPlanExpiration(const string symbol)
   {
      int slot = FindSlot(symbol);
      if(slot < 0) return false;

      if(m_states[slot].latest_plan.plan_status == TRADE_PLAN_VALID)
      {
         if(TimeCurrent() > m_states[slot].latest_plan.expiration_time)
         {
            m_states[slot].latest_plan.plan_status      = TRADE_PLAN_EXPIRED;
            m_states[slot].latest_plan.status           = TRADE_PLAN_EXPIRED;
            m_states[slot].latest_plan.rejection_reason = PLAN_REJECT_EXPIRED;
            m_states[slot].latest_plan.rejection_detail = "Plan expired after validity window.";
            FormatPlan(m_states[slot].latest_plan);

            if(m_logger != NULL)
            {
               m_logger.Log(LOG_LEVEL_INFO, "TradePlanner", "TRADE_PLAN_EXPIRED",
                  StringFormat("%s: Trade plan #%I64u has expired.", symbol, m_states[slot].latest_plan.plan_id));
            }
            return true;
         }
      }
      return false;
   }

private:
   //+----------------------------------------------------------------+
   //| Reject plan with reason                                        |
   //+----------------------------------------------------------------+
   void RejectPlan(STradePlan &plan,
                   ENUM_PLAN_REJECTION_REASON reason,
                   const string detail)
   {
      if(plan.plan_status != TRADE_PLAN_INSUFFICIENT_DATA && plan.plan_status != TRADE_PLAN_EXPIRED)
      {
         plan.plan_status = TRADE_PLAN_REJECTED;
         plan.status      = TRADE_PLAN_REJECTED;
      }
      plan.rejection_reason      = reason;
      plan.rejection_detail      = detail;
      plan.execution_authorized  = false;   // Always false
      FormatPlan(plan);

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_DEBUG, "TradePlanner", "TRADE_PLAN_REJECTED",
            StringFormat("%s: Plan rejected - %s: %s",
               plan.symbol, plan.RejectionToString(), detail));
      }
   }
};

#endif
