// MarketStateCache.mqh

enum ENUM_DATA_HEALTH {
    DATA_READY,
    DATA_PARTIAL,
    DATA_UNAVAILABLE
};

struct CSymbolState {
    string symbol;
    bool enabled;
    double bid;
    double ask;
    double last;
    int spread_points;
    double spread_price;
    datetime tick_time;
    ulong tick_time_msc;
    uint tick_flags;
    int digits;
    double point;
    double tick_size;
    double tick_value;
    double volume_min;
    double volume_max;
    double volume_step;
    int stops_level;
    int freeze_level;
    datetime last_update_time;
    ENUM_DATA_HEALTH data_health;
};

struct CBarState {
    datetime time;
    double open;
    double high;
    double low;
    double close;
    long tick_volume;
    long real_volume;
    int spread;
};

class CMarketStateCache {
public:
    CSymbolState symbols[];
    
    void Initialize(int count) {
        ArrayResize(symbols, count);
    }
};
