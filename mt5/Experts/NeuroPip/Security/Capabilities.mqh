// Capabilities.mqh

class CCapabilities {
public:
    bool can_monitor;
    bool can_analyze;
    bool can_trade;
    
    CCapabilities() {
        can_monitor = true;
        can_analyze = true;  // Phase 3 Market Intelligence enabled
        can_trade = false;   // Trading remains strictly disabled
    }
};
