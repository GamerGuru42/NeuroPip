//+------------------------------------------------------------------+
//| ForwardAlertManager.mqh                                          |
//| ATG Trading Engine - Phase 10                                    |
//| Forward Monitoring Diagnostic Alert Dispatcher                   |
//| DIAGNOSTICS/ALERTS ONLY - No automatic strategy modifications    |
//+------------------------------------------------------------------+
#ifndef ATG_FORWARD_ALERT_MANAGER_MQH
#define ATG_FORWARD_ALERT_MANAGER_MQH

#include "ForwardEvidenceTypes.mqh"
#include "../Diagnostics/Logger.mqh"
#include "../Persistence/PersistenceTypes.mqh"
#include "../Persistence/PaperTradeStorage.mqh"

//+------------------------------------------------------------------+
//| CForwardAlertManager                                             |
//+------------------------------------------------------------------+
class CForwardAlertManager
{
private:
   CLogger*            m_logger;
   CPaperTradeStorage* m_storage;
   int                 m_alert_counts[9]; // Indexed by ENUM_FORWARD_ALERT_TYPE
   SForwardAlertRecord m_recent_alerts[];
   int                 m_max_recent;

public:
   CForwardAlertManager(CLogger* logger = NULL, CPaperTradeStorage* storage = NULL)
      : m_logger(logger),
        m_storage(storage),
        m_max_recent(100)
   {
      Reset();
   }

   void SetLogger(CLogger* logger)         { m_logger = logger; }
   void SetStorage(CPaperTradeStorage* st) { m_storage = st; }

   void Reset()
   {
      for(int i = 0; i < 9; i++)
         m_alert_counts[i] = 0;
      ArrayResize(m_recent_alerts, 0);
   }

   //+----------------------------------------------------------------+
   //| Emit diagnostic alert                                          |
   //| NOTE: Diagnostics/alerts only. Zero strategy modifications.    |
   //+----------------------------------------------------------------+
   bool EmitAlert(ENUM_FORWARD_ALERT_TYPE type,
                  const string severity,
                  const string source,
                  const string message,
                  const string action_taken = "FLAGGED_ONLY",
                  const string cohort_id = "COHORT_01")
   {
      if((int)type >= 0 && (int)type < 9)
         m_alert_counts[(int)type]++;

      SForwardAlertRecord rec;
      rec.timestamp    = TimeCurrent();
      rec.alert_type   = type;
      rec.severity     = severity;
      rec.source       = source;
      rec.message      = message;
      rec.action_taken = action_taken;
      rec.cohort_id    = cohort_id;

      int idx = ArraySize(m_recent_alerts);
      if(idx >= m_max_recent)
      {
         for(int i = 0; i < m_max_recent - 1; i++)
            m_recent_alerts[i] = m_recent_alerts[i + 1];
         m_recent_alerts[m_max_recent - 1] = rec;
      }
      else
      {
         ArrayResize(m_recent_alerts, idx + 1);
         m_recent_alerts[idx] = rec;
      }

      // Log appropriately
      ENUM_LOG_LEVEL log_level = LOG_LEVEL_NOTICE;
      if(severity == "CRITICAL")
         log_level = LOG_LEVEL_CRITICAL;
      else if(severity == "WARNING")
         log_level = LOG_LEVEL_WARNING;

      if(m_logger != NULL)
      {
         m_logger.Log(log_level, "ForwardAlert", ForwardAlertTypeToString(type),
            StringFormat("[%s] from %s: %s | Action: %s | Cohort: %s",
               severity, source, message, action_taken, cohort_id));
      }

      // Append to audit trail
      if(m_storage != NULL && m_storage.IsEnabled())
      {
         m_storage.AppendAudit(AUDIT_ALERT_TRIGGERED, 0, source,
            StringFormat("ALERT_%s: %s (%s)", ForwardAlertTypeToString(type), message, action_taken));
      }

      return true;
   }

   int GetAlertCount(ENUM_FORWARD_ALERT_TYPE type) const
   {
      if((int)type >= 0 && (int)type < 9)
         return m_alert_counts[(int)type];
      return 0;
   }

   int GetTotalAlerts() const
   {
      int sum = 0;
      for(int i = 0; i < 9; i++)
         sum += m_alert_counts[i];
      return sum;
   }

   int GetRecentAlerts(SForwardAlertRecord &out_alerts[]) const
   {
      int n = ArraySize(m_recent_alerts);
      ArrayResize(out_alerts, n);
      for(int i = 0; i < n; i++)
         out_alerts[i] = m_recent_alerts[i];
      return n;
   }
};

#endif
