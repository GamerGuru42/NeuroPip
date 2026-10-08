// Logger.mqh
#include "../Config/Config.mqh"

class CLogger {
private:
    ENUM_LOG_LEVEL m_min_level;

    string LevelToString(ENUM_LOG_LEVEL level) {
        switch(level) {
            case LOG_LEVEL_DEBUG: return "DEBUG";
            case LOG_LEVEL_INFO: return "INFO";
            case LOG_LEVEL_NOTICE: return "NOTICE";
            case LOG_LEVEL_WARNING: return "WARNING";
            case LOG_LEVEL_ERROR: return "ERROR";
            case LOG_LEVEL_CRITICAL: return "CRITICAL";
        }
        return "UNKNOWN";
    }

public:
    CLogger(ENUM_LOG_LEVEL min_level = LOG_LEVEL_DEBUG) : m_min_level(min_level) {}

    void Log(ENUM_LOG_LEVEL level, string module, string event_code, string message) {
        if (level < m_min_level) return;
        string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
        string log_str = StringFormat("%s | %s | %s | %s | %s", time_str, LevelToString(level), module, event_code, message);
        Print(log_str);
    }
};
