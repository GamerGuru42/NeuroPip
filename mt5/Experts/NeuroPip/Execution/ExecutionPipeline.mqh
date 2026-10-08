// ExecutionPipeline.mqh
// Phase 2D/2F — Execution Pipeline (Dry-Run)
// Orchestrates the complete execution pipeline from intent to guard rejection.
// This is the central coordinator that runs a trade intent through every stage.
//
// Pipeline flow:
//   Trade Intent
//     → Risk Validation / Position Sizing
//     → Execution Validator
//     → Execution Request Builder
//     → Broker OrderCheck
//     → Execution Reconciliation
//     → Execution Guard
//     → STOP (REJECTED while can_trade == false)
//
#property copyright "NextGen Technologies"
#property link      ""

#include "ExecutionTypes.mqh"
#include "ExecutionValidator.mqh"
#include "ExecutionRequestBuilder.mqh"
#include "OrderCheckEngine.mqh"
#include "ExecutionReconciliation.mqh"
#include "ExecutionGuard.mqh"
#include "RiskEngine.mqh"
#include "PositionSizer.mqh"
#include "../Diagnostics/Logger.mqh"

class CExecutionPipeline {
private:
    CLogger*                    m_logger;
    CRiskEngine*                m_risk_engine;
    CPositionSizer*             m_position_sizer;
    CExecutionValidator*        m_validator;
    CExecutionRequestBuilder*   m_request_builder;
    COrderCheckEngine*          m_order_check;
    CExecutionGuard*            m_guard;

    ulong m_next_request_id;

public:
    CExecutionPipeline(CLogger* logger,
                       CRiskEngine* risk_engine,
                       CPositionSizer* position_sizer,
                       CExecutionValidator* validator,
                       CExecutionRequestBuilder* request_builder,
                       COrderCheckEngine* order_check,
                       CExecutionGuard* guard)
        : m_logger(logger),
          m_risk_engine(risk_engine),
          m_position_sizer(position_sizer),
          m_validator(validator),
          m_request_builder(request_builder),
          m_order_check(order_check),
          m_guard(guard) {
        m_next_request_id = 1;
    }

    //--- Run the full dry-run pipeline for a trade intent.
    //--- Returns the complete reconciliation record.
    SExecutionReconciliation ProcessIntent(SATGTradeIntent &intent) {
        SExecutionReconciliation recon;
        recon.Init();
        recon.pipeline_start = TimeCurrent();

        // Assign a unique request ID
        intent.request_id = m_next_request_id++;

        // Capture the original intent
        recon.CaptureIntent(intent);

        m_logger.Log(LOG_LEVEL_INFO, "Pipeline", "PIPELINE_START",
            StringFormat("=== Pipeline RUN #%d: %s %s ===",
                intent.request_id, intent.symbol,
                intent.direction == ATG_DIRECTION_BUY ? "BUY" : "SELL"));

        // STAGE 1: Risk Validation
        SRiskResult risk_result;
        if(!m_risk_engine.Evaluate(intent, risk_result)) {
            recon.CaptureRiskResult(risk_result);
            recon.Finalize(intent);
            LogPipelineResult(intent, recon, "RISK_VALIDATION");
            return recon;
        }
        recon.CaptureRiskResult(risk_result);

        // STAGE 2: Position Sizing (if volume not pre-set)
        if(intent.volume <= 0 || intent.volume == 0) {
            if(!m_position_sizer.CalculateVolume(intent, risk_result.intended_risk_amount)) {
                intent.state         = ATG_STATE_REJECTED;
                intent.reject_reason = ATG_REJECT_INVALID_VOLUME;
                intent.reject_detail = "Position sizer could not calculate a valid volume.";
                recon.Finalize(intent);
                LogPipelineResult(intent, recon, "POSITION_SIZING");
                return recon;
            }
        }

        // STAGE 3: Execution Validation
        if(!m_validator.Validate(intent)) {
            recon.Finalize(intent);
            LogPipelineResult(intent, recon, "EXECUTION_VALIDATION");
            return recon;
        }

        // STAGE 4: Execution Request Construction (Phase 2F)
        MqlTradeRequest request;
        SBuiltRequest built;
        if(!m_request_builder.Build(intent, request, built)) {
            recon.built_request = built;
            recon.Finalize(intent);
            LogPipelineResult(intent, recon, "REQUEST_BUILD");
            return recon;
        }
        recon.built_request = built;
        m_logger.Log(LOG_LEVEL_INFO, "Pipeline", "REQUEST_BUILT",
            StringFormat("Request built: Symbol=%s | Action=%d | Type=%s | Vol=%.4f | Price=%.5f | SL=%.5f | TP=%.5f",
                built.broker_symbol, (int)built.trade_action,
                built.order_type == ORDER_TYPE_BUY ? "BUY" : "SELL",
                built.normalized_volume, built.normalized_price,
                built.normalized_sl, built.normalized_tp));

        // STAGE 5: Broker OrderCheck Preflight
        SOrderCheckResult check_result;
        // Use the built request's broker symbol for the check
        // OrderCheckEngine.CheckOrder rebuilds the request internally,
        // but we need to run it for the broker validation
        if(!m_order_check.CheckOrder(intent, check_result)) {
            recon.order_check_result = check_result;
            recon.Finalize(intent);
            LogPipelineResult(intent, recon, "ORDER_CHECK");
            return recon;
        }
        recon.order_check_result = check_result;
        m_logger.Log(LOG_LEVEL_INFO, "Pipeline", "ORDERCHECK",
            StringFormat("Broker preflight passed: Symbol=%s | Retcode=%u | MarginFree=%.2f | Margin=%.2f | Comment=%s",
                built.broker_symbol, check_result.retcode, check_result.margin_free, check_result.margin, check_result.comment));

        // STAGE 6: Reconciliation state is captured
        intent.state = ATG_STATE_RECONCILED;
        m_logger.Log(LOG_LEVEL_INFO, "Pipeline", "RECONCILIATION",
            StringFormat("Reconciliation audit recorded: RequestID=%I64u | Symbol=%s | Volume=%.4f | State=RECONCILED",
                intent.request_id, intent.symbol, intent.volume));

        // STAGE 7: Execution Guard (Final Safety Barrier)
        bool allowed = m_guard.IsExecutionAllowed(intent);
        recon.CaptureGuardResult(allowed, intent.reject_reason,
            intent.reject_detail, intent.state);

        if(!allowed && intent.reject_reason == ATG_REJECT_EXECUTION_DISABLED) {
            m_logger.Log(LOG_LEVEL_INFO, "Pipeline", "GUARD_REJECTED",
                StringFormat("Order blocked by safety guard: ATG_REJECT_EXECUTION_DISABLED (%s)",
                    intent.reject_detail));
        }

        recon.Finalize(intent);
        LogPipelineResult(intent, recon, "GUARD");

        return recon;
    }

private:
    void LogPipelineResult(const SATGTradeIntent &intent,
                           const SExecutionReconciliation &recon,
                           const string &stopped_at) {
        string status = (intent.state == ATG_STATE_REJECTED) ? "REJECTED" : "COMPLETED";
        string reason = (intent.reject_reason == ATG_REJECT_NONE)
            ? "N/A" : intent.reject_detail;

        m_logger.Log(LOG_LEVEL_INFO, "Pipeline", "PIPELINE_RESULT",
            StringFormat("Pipeline #%d [%s] stopped at %s — %s: %s",
                intent.request_id, intent.symbol,
                stopped_at, status, reason));
    }
};
