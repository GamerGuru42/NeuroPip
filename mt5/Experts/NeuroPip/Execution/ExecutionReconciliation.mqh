// ExecutionReconciliation.mqh
// Phase 2F — Execution Reconciliation Structure
// Records the complete audit trail of a trade intent as it flows through the
// execution pipeline. This is an audit/reconciliation structure, NOT a live
// execution system.
#property copyright "NextGen Technologies"
#property link      ""

#include "ExecutionTypes.mqh"
#include "ExecutionRequestBuilder.mqh"
#include "OrderCheckEngine.mqh"
#include "RiskEngine.mqh"

//--- Guard result snapshot
struct SGuardResult {
    bool                    execution_allowed;
    ENUM_ATG_REJECT_REASON  reject_reason;
    string                  reject_detail;
    ENUM_ATG_EXEC_STATE     final_state;
};

//--- Complete reconciliation record for a single pipeline run
struct SExecutionReconciliation {
    // === INTENT ===
    ulong                   request_id;
    string                  intent_symbol;
    ENUM_ATG_DIRECTION      intent_direction;
    double                  intent_volume;
    double                  intent_entry_price;
    double                  intent_sl;
    double                  intent_tp;
    double                  intent_risk_percent;
    ENUM_ATG_INTENT_SOURCE  intent_source;
    string                  intent_strategy;
    string                  intent_comment;
    datetime                intent_created;

    // === RISK RESULT ===
    bool                    risk_approved;
    double                  risk_max_amount;
    double                  risk_intended_amount;
    double                  risk_equity_pct;
    double                  risk_equity;
    double                  risk_free_margin;
    string                  risk_reject_detail;

    // === CONSTRUCTED REQUEST ===
    SBuiltRequest           built_request;

    // === BROKER PREFLIGHT (OrderCheck) ===
    SOrderCheckResult       order_check_result;

    // === GUARD RESULT ===
    SGuardResult            guard_result;

    // === PIPELINE METADATA ===
    datetime                pipeline_start;
    datetime                pipeline_end;
    ENUM_ATG_EXEC_STATE     final_state;
    ENUM_ATG_REJECT_REASON  final_reject_reason;
    string                  final_reject_detail;
    bool                    pipeline_completed;

    //--- Initialize all fields
    void Init() {
        request_id          = 0;
        intent_symbol       = "";
        intent_direction    = ATG_DIRECTION_BUY;
        intent_volume       = 0;
        intent_entry_price  = 0;
        intent_sl           = 0;
        intent_tp           = 0;
        intent_risk_percent = 0;
        intent_source       = ATG_SOURCE_SYSTEM_TEST;
        intent_strategy     = "";
        intent_comment      = "";
        intent_created      = 0;

        risk_approved       = false;
        risk_max_amount     = 0;
        risk_intended_amount = 0;
        risk_equity_pct     = 0;
        risk_equity         = 0;
        risk_free_margin    = 0;
        risk_reject_detail  = "";

        ZeroMemory(built_request);
        ZeroMemory(order_check_result);
        ZeroMemory(guard_result);

        pipeline_start      = 0;
        pipeline_end        = 0;
        final_state         = ATG_STATE_CREATED;
        final_reject_reason = ATG_REJECT_NONE;
        final_reject_detail = "";
        pipeline_completed  = false;
    }

    //--- Capture intent snapshot
    void CaptureIntent(const SATGTradeIntent &intent) {
        request_id          = intent.request_id;
        intent_symbol       = intent.symbol;
        intent_direction    = intent.direction;
        intent_volume       = intent.volume;
        intent_entry_price  = intent.entry_price;
        intent_sl           = intent.sl_price;
        intent_tp           = intent.tp_price;
        intent_risk_percent = intent.risk_percent;
        intent_source       = intent.source;
        intent_strategy     = intent.strategy_name;
        intent_comment      = intent.comment;
        intent_created      = intent.created_time;
    }

    //--- Capture risk result
    void CaptureRiskResult(const SRiskResult &risk) {
        risk_approved        = risk.approved;
        risk_max_amount      = risk.max_risk_amount;
        risk_intended_amount = risk.intended_risk_amount;
        risk_equity_pct      = risk.equity_at_risk_pct;
        risk_equity          = risk.current_equity;
        risk_free_margin     = risk.current_free_margin;
        risk_reject_detail   = risk.reason;
    }

    //--- Capture guard result
    void CaptureGuardResult(bool allowed, ENUM_ATG_REJECT_REASON reason,
                            const string &detail, ENUM_ATG_EXEC_STATE state) {
        guard_result.execution_allowed = allowed;
        guard_result.reject_reason     = reason;
        guard_result.reject_detail     = detail;
        guard_result.final_state       = state;
    }

    //--- Finalize the reconciliation record
    void Finalize(const SATGTradeIntent &intent) {
        pipeline_end        = TimeCurrent();
        final_state         = intent.state;
        final_reject_reason = intent.reject_reason;
        final_reject_detail = intent.reject_detail;
        pipeline_completed  = true;
    }
};
