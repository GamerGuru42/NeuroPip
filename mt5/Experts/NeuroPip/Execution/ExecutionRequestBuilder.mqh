// ExecutionRequestBuilder.mqh
// Phase 2F — Execution Request Construction Layer
// Accepts a validated SATGTradeIntent and constructs a normalized MqlTradeRequest.
// REUSES the COrderCheckEngine's request-building and symbol-resolution logic
// rather than duplicating it.
#property copyright "ATG"
#property link      ""

#include "TradeTypes.mqh"
#include "OrderCheckEngine.mqh"
#include "../MarketData/MarketStateCache.mqh"
#include "../Diagnostics/Logger.mqh"

//--- Snapshot of the constructed request for reconciliation
struct SBuiltRequest {
    bool                        valid;
    string                      broker_symbol;         // Resolved broker symbol (e.g., EURUSDm)
    double                      normalized_volume;
    double                      normalized_price;
    double                      normalized_sl;
    double                      normalized_tp;
    ENUM_ORDER_TYPE             order_type;
    ENUM_ORDER_TYPE_FILLING     filling_mode;
    ENUM_TRADE_REQUEST_ACTIONS  trade_action;
    ulong                       magic;
    string                      comment;
    int                         deviation;
    ENUM_SYMBOL_TRADE_EXECUTION execution_mode;
    string                      error_detail;
};

class CExecutionRequestBuilder {
private:
    CLogger*            m_logger;
    COrderCheckEngine*  m_order_check;      // Reuse existing request-building logic
    CMarketStateCache*  m_cache;

public:
    CExecutionRequestBuilder(CLogger* logger, COrderCheckEngine* order_check, CMarketStateCache* cache = NULL)
        : m_logger(logger), m_order_check(order_check), m_cache(cache) {}

    //--- Build a normalized MqlTradeRequest and capture its snapshot
    bool Build(SATGTradeIntent &intent, MqlTradeRequest &request, SBuiltRequest &snapshot) {
        ZeroMemory(snapshot);
        snapshot.valid = false;

        // 1. Resolve the actual broker symbol
        string broker_symbol = m_order_check.ResolveBrokerSymbol(intent.symbol);
        snapshot.broker_symbol = broker_symbol;

        // 2. Get execution mode for logging/audit
        snapshot.execution_mode = m_order_check.GetExecutionMode(broker_symbol);

        // 3. Delegate request construction to COrderCheckEngine's shared logic
        if(!m_order_check.BuildTradeRequest(intent, broker_symbol, request)) {
            snapshot.error_detail = StringFormat("Request build failed for %s (broker: %s)",
                intent.symbol, broker_symbol);
            intent.state         = ATG_STATE_REJECTED;
            intent.reject_reason = ATG_REJECT_REQUEST_BUILD_FAILED;
            intent.reject_detail = snapshot.error_detail;
            m_logger.Log(LOG_LEVEL_ERROR, "RequestBuilder", "BUILD_FAILED", snapshot.error_detail);
            return false;
        }

        // 4. Capture snapshot of the built request
        snapshot.valid             = true;
        snapshot.normalized_volume = request.volume;
        snapshot.normalized_price  = request.price;
        snapshot.normalized_sl     = request.sl;
        snapshot.normalized_tp     = request.tp;
        snapshot.order_type        = request.type;
        snapshot.filling_mode      = request.type_filling;
        snapshot.trade_action      = request.action;
        snapshot.magic             = request.magic;
        snapshot.comment           = request.comment;
        snapshot.deviation         = (int)request.deviation;

        intent.state = ATG_STATE_REQUEST_BUILT;

        m_logger.Log(LOG_LEVEL_DEBUG, "RequestBuilder", "BUILD_SUCCESS",
            StringFormat("%s -> %s | %s Vol=%.4f Price=%.5f SL=%.5f TP=%.5f Fill=%s",
                intent.symbol, broker_symbol,
                request.type == ORDER_TYPE_BUY ? "BUY" : "SELL",
                request.volume, request.price, request.sl, request.tp,
                FillingModeToString(request.type_filling)));
        return true;
    }

private:
    string FillingModeToString(ENUM_ORDER_TYPE_FILLING filling) {
        switch(filling) {
            case ORDER_FILLING_FOK:    return "FOK";
            case ORDER_FILLING_IOC:    return "IOC";
            case ORDER_FILLING_RETURN: return "RETURN";
        }
        return "UNKNOWN";
    }
};
