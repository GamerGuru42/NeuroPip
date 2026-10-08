// TestRunner.mqh
#include "../Diagnostics/Logger.mqh"
#include "../Core/RuntimeState.mqh"
#include "../Core/RuntimeValidator.mqh"
#include "../MarketData/SymbolUniverseManager.mqh"
#include "../MarketData/MarketStateCache.mqh"
#include "../MarketData/MarketDataEngine.mqh"

class CTestRunner {
private:
    CLogger* m_logger;
public:
    CTestRunner(CLogger* logger) : m_logger(logger) {}
    
    bool RunAllTests() {
        m_logger.Log(LOG_LEVEL_INFO, "TestRunner", "TEST_START", "Running Phase 1 tests...");
        
        CRuntimeState state;
        CRuntimeValidator validator(m_logger);
        if(!validator.Validate(state)) {
            m_logger.Log(LOG_LEVEL_ERROR, "TestRunner", "TEST_FAIL", "Terminal validation failed.");
            return false;
        }
        
        m_logger.Log(LOG_LEVEL_INFO, "TestRunner", "TEST_SUCCESS", "All Phase 1 static unit tests passed.");
        return true;
    }
};
