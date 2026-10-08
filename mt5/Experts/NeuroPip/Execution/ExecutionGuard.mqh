//+------------------------------------------------------------------+
//| ExecutionGuard.mqh                                               |
//| NeuroPip - Phase 2A                                   |
//| Execution Safety Gate                                            |
//|                                                                  |
//| Phase 2A does NOT execute trades.                                |
//+------------------------------------------------------------------+
#ifndef ATG_EXECUTION_GUARD_MQH
#define ATG_EXECUTION_GUARD_MQH

#include "../Diagnostics/Logger.mqh"
#include "../Core/RuntimeState.mqh"
#include "../Security/Capabilities.mqh"
#include "TradeTypes.mqh"

class CExecutionGuard
{
private:

   CLogger* m_logger;
   CCapabilities* m_capabilities;
   CRuntimeState* m_runtime;

public:

   CExecutionGuard(
      CLogger* logger,
      CCapabilities* capabilities,
      CRuntimeState* runtime
   )
      : m_logger(logger),
        m_capabilities(capabilities),
        m_runtime(runtime)
   {
   }

   //+--------------------------------------------------------------+
   //| Determine whether execution is permitted                    |
   //+--------------------------------------------------------------+
   bool IsExecutionAllowed()
   {
      if(m_capabilities == NULL)
         return false;

      if(m_runtime == NULL)
         return false;

      // -----------------------------------------------------------
      // Phase 2A hard safety gate.
      // Trading must remain disabled.
      // -----------------------------------------------------------
      if(!m_capabilities.can_trade)
         return false;

      if(!m_runtime.initialized)
         return false;

      if(!m_runtime.terminal_connected)
         return false;

      if(!m_runtime.safe_state)
         return false;

      if(m_runtime.mode == MODE_ERROR)
         return false;

      return true;
   }

   //+--------------------------------------------------------------+
   //| Determine whether execution is permitted for intent          |
   //+--------------------------------------------------------------+
   bool IsExecutionAllowed(
      SATGTradeIntent &intent
   )
   {
      return Validate(intent);
   }

   //+--------------------------------------------------------------+
   //| Validate execution request                                   |
   //+--------------------------------------------------------------+
   bool Validate(
      SATGTradeIntent &intent
   )
   {
      intent.state =
         ATG_EXECUTION_VALIDATING;

      intent.rejection_reason =
         ATG_REJECT_NONE;

      // -----------------------------------------------------------
      // Hard capability check
      // -----------------------------------------------------------
      if(m_capabilities == NULL ||
         !m_capabilities.can_trade)
      {
         intent.state =
            ATG_EXECUTION_REJECTED;

         intent.rejection_reason =
            ATG_REJECT_EXECUTION_DISABLED;

         intent.reject_detail =
            "Trading capability is disabled.";

         LogRejection(
            intent,
            "Trading capability is disabled."
         );

         return false;
      }

      // -----------------------------------------------------------
      // Runtime checks
      // -----------------------------------------------------------
      if(m_runtime == NULL ||
         !m_runtime.initialized)
      {
         Reject(
            intent,
            ATG_REJECT_RUNTIME,
            "Runtime is not initialized."
         );

         return false;
      }

      if(!m_runtime.terminal_connected)
      {
         Reject(
            intent,
            ATG_REJECT_RUNTIME,
            "Terminal is disconnected."
         );

         return false;
      }

      if(!m_runtime.safe_state)
      {
         Reject(
            intent,
            ATG_REJECT_SAFE_STATE,
            "Runtime is not in a safe state."
         );

         return false;
      }

      if(m_runtime.mode == MODE_ERROR)
      {
         Reject(
            intent,
            ATG_REJECT_RUNTIME,
            "Runtime is in ERROR mode."
         );

         return false;
      }

      // -----------------------------------------------------------
      // Basic request validation
      // -----------------------------------------------------------
      if(intent.symbol == "")
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_SYMBOL,
            "Trade intent contains no symbol."
         );

         return false;
      }

      if(intent.direction != ATG_DIRECTION_BUY &&
         intent.direction != ATG_DIRECTION_SELL)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_DIRECTION,
            "Trade intent contains an invalid direction."
         );

         return false;
      }

      if(intent.volume <= 0.0)
      {
         Reject(
            intent,
            ATG_REJECT_INVALID_VOLUME,
            "Trade intent contains an invalid volume."
         );

         return false;
      }

      intent.state =
         ATG_EXECUTION_CHECKED;

      return true;
   }

private:

   //+--------------------------------------------------------------+
   //| Reject request                                                |
   //+--------------------------------------------------------------+
   void Reject(
      SATGTradeIntent &intent,
      ENUM_ATG_REJECTION_REASON reason,
      string message
   )
   {
      intent.state =
         ATG_EXECUTION_REJECTED;

      intent.rejection_reason =
         reason;

      intent.reject_detail =
         message;

      LogRejection(
         intent,
         message
      );
   }

   //+--------------------------------------------------------------+
   //| Log rejection                                                 |
   //+--------------------------------------------------------------+
   void LogRejection(
      SATGTradeIntent &intent,
      string message
   )
   {
      if(m_logger == NULL)
         return;

      m_logger.Log(
         LOG_LEVEL_NOTICE,
         "ExecutionGuard",
         "EXECUTION_REJECTED",
         StringFormat(
            "Request=%I64u | Symbol=%s | Reason=%s",
            intent.request_id,
            intent.symbol,
            message
         )
      );
   }
};

#endif

//+------------------------------------------------------------------+