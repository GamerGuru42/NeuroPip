// RuntimeState.mqh

enum ENUM_RUNTIME_MODE {
    MODE_MONITOR_ONLY,
    MODE_SAFE,
    MODE_ERROR
};

class CRuntimeState {
public:
    bool initialized;
    ENUM_RUNTIME_MODE mode;
    
    // Account Info
    long account_login;
    string account_name;
    string broker;
    string server;
    string account_currency;
    double balance;
    double equity;
    double margin;
    double free_margin;
    double margin_level;
    long leverage;
    bool trade_allowed;
    bool algo_allowed;
    
    // Terminal
    bool terminal_connected;
    
    // Stats
    int total_symbols;
    int healthy_symbols;
    datetime last_successful_update;
    datetime last_diagnostic_run;
    int runtime_errors;
    bool safe_state;

    CRuntimeState() {
        initialized = false;
        mode = MODE_MONITOR_ONLY;
        account_login = 0;
        total_symbols = 0;
        healthy_symbols = 0;
        runtime_errors = 0;
        safe_state = false;
    }
};
