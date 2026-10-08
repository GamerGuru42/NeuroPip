//+------------------------------------------------------------------+
//| RiskEngine.mqh                                                   |
//| NeuroPip - Phase 2E                                   |
//| Canonical Location: Execution/RiskEngine.mqh                     |
//|                                                                  |
//| Risk Management Engine                                           |
//| Computes allowed cash risk from account equity and risk limits.  |
//| No live orders are sent.                                         |
//+------------------------------------------------------------------+
#ifndef ATG_RISK_ENGINE_MQH
#define ATG_RISK_ENGINE_MQH

#include "../Diagnostics/Logger.mqh"
#include "TradeTypes.mqh"

//+------------------------------------------------------------------+
//| Risk evaluation result                                           |
//+------------------------------------------------------------------+
struct SATGRiskResult
{
   bool   approved;
   double equity;
   double risk_percent;
   double risk_money;
   string reason;
};

// Aliases for compatibility
#define SRiskResult SATGRiskResult
#define max_risk_amount risk_money
#define intended_risk_amount risk_money
#define current_equity equity
#define current_free_margin equity
#define equity_at_risk_pct risk_percent

class CRiskEngine
{
private:
   CLogger* m_logger;
   double   m_max_risk_pct;
   double   m_default_risk_pct;
   double   m_simulation_equity;
   bool     m_use_simulation_equity;

public:
   CRiskEngine(CLogger* logger)
      : m_logger(logger),
        m_max_risk_pct(2.0),
        m_default_risk_pct(1.0),
        m_simulation_equity(10.0),
        m_use_simulation_equity(false)
   {
   }

   double GetDefaultRiskPercent() const { return m_default_risk_pct; }
   double GetMaxRiskPercent() const     { return m_max_risk_pct; }

   void SetMaxRiskPerTrade(double pct)     { m_max_risk_pct = pct; }
   void SetDefaultRiskPercent(double pct)  { m_default_risk_pct = pct; }
   void SetSimulationEquity(double eq)     { m_simulation_equity = eq; }
   void SetUseSimulationEquity(bool use)   { m_use_simulation_equity = use; }
   double GetSimulationEquity() const      { return m_simulation_equity; }
   bool IsUsingSimulationEquity() const    { return m_use_simulation_equity; }

   bool Calculate(const string symbol,
                  double entry,
                  double stop_loss,
                  double risk_percent,
                  SATGRiskResult &result)
   {
      ZeroMemory(result);
      double equity = (m_use_simulation_equity && m_simulation_equity > 0.0)
         ? m_simulation_equity
         : AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0)
      {
         result.approved = false;
         result.reason = "Invalid or non-positive equity.";
         return false;
      }

      if(risk_percent <= 0.0)
         risk_percent = m_default_risk_pct;

      if(risk_percent > m_max_risk_pct)
      {
         result.approved = false;
         result.reason = StringFormat("Risk %.2f%% exceeds max %.2f%%", risk_percent, m_max_risk_pct);
         return false;
      }

      result.equity = equity;
      result.risk_percent = risk_percent;
      result.risk_money = equity * (risk_percent / 100.0);
      result.approved = true;
      result.reason = "Risk calculated successfully.";
      return true;
   }

   bool Evaluate(SATGTradeIntent &intent, SATGRiskResult &result)
   {
      double entry = intent.requested_price;
      double sl = intent.stop_loss;
      double risk_pct = (intent.risk_percent > 0) ? intent.risk_percent : m_default_risk_pct;
      bool res = Calculate(intent.symbol, entry, sl, risk_pct, result);
      intent.risk_approved = res;
      if(!res)
      {
         intent.state = ATG_EXECUTION_REJECTED;
         intent.rejection_reason = ATG_REJECT_RISK;
      }
      return res;
   }
};

#endif
