// RuntimeValidator.mqh
#include "RuntimeState.mqh"
#include "../Diagnostics/Logger.mqh"

class CRuntimeValidator {
private:
    CLogger* m_logger;
public:
    CRuntimeValidator(CLogger* logger) : m_logger(logger) {}
    
    bool Validate(CRuntimeState &state) {
        // Allow up to 120 seconds for initial terminal network connection on startup
        int wait_count = 0;
        while (!TerminalInfoInteger(TERMINAL_CONNECTED) && wait_count < 240 && !IsStopped()) {
            Sleep(500);
            wait_count++;
        }
        
        state.terminal_connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
        state.account_login = AccountInfoInteger(ACCOUNT_LOGIN);
        state.account_name = AccountInfoString(ACCOUNT_NAME);
        state.broker = AccountInfoString(ACCOUNT_COMPANY);
        state.server = AccountInfoString(ACCOUNT_SERVER);
        state.account_currency = AccountInfoString(ACCOUNT_CURRENCY);
        state.balance = AccountInfoDouble(ACCOUNT_BALANCE);
        state.equity = AccountInfoDouble(ACCOUNT_EQUITY);
        state.margin = AccountInfoDouble(ACCOUNT_MARGIN);
        state.free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        state.margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
        state.leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
        state.trade_allowed = (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
        state.algo_allowed = (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
        
        if (!state.terminal_connected) {
            m_logger.Log(LOG_LEVEL_ERROR, "RuntimeValidator", "TERMINAL_DISCONNECTED", "Terminal is not connected to the broker.");
            return false;
        }
        if (state.account_login == 0) {
            m_logger.Log(LOG_LEVEL_ERROR, "RuntimeValidator", "ACCOUNT_DISCONNECTED", "No account is logged in.");
            return false;
        }
        
        m_logger.Log(LOG_LEVEL_INFO, "RuntimeValidator", "VALIDATION_SUCCESS", StringFormat("Account %d on %s validated.", state.account_login, state.broker));
        return true;
    }
};
