//+------------------------------------------------------------------+
//| SymbolUniverseManager.mqh                                       |
//| ATG Trading Engine - Phase 1                                    |
//|                                                                  |
//| Resolves configured symbols to the actual broker symbols.       |
//| Example:                                                        |
//|   EURUSD  -> EURUSDm                                            |
//|   XAUUSD  -> XAUUSDm                                            |
//|   BTCUSD  -> BTCUSDm                                            |
//|                                                                  |
//| No trading operations are performed by this component.          |
//+------------------------------------------------------------------+

#ifndef __ATG_SYMBOL_UNIVERSE_MANAGER_MQH__
#define __ATG_SYMBOL_UNIVERSE_MANAGER_MQH__

#include "../Diagnostics/Logger.mqh"


//+------------------------------------------------------------------+
//| Symbol operating mode                                            |
//+------------------------------------------------------------------+
enum ENUM_SYMBOL_MODE
{
    SYMBOL_MODE_AUTO,
    SYMBOL_MODE_WATCH,
    SYMBOL_MODE_DISABLED
};


//+------------------------------------------------------------------+
//| Symbol information                                               |
//+------------------------------------------------------------------+
struct SSymbolInfo
{
    // Configured/base symbol.
    string configured_name;

    // Actual symbol name used by the broker/terminal.
    string name;

    // Whether the symbol is available.
    bool available;

    // Current operating mode.
    ENUM_SYMBOL_MODE mode;
};


//+------------------------------------------------------------------+
//| Symbol Universe Manager                                          |
//+------------------------------------------------------------------+
class CSymbolUniverseManager
{
private:

    CLogger* m_logger;

    SSymbolInfo m_symbols[];


    // ---------------------------------------------------------------
    // Normalize symbol for comparison.
    // ---------------------------------------------------------------
    string NormalizeSymbol(string symbol)
    {
        StringToUpper(symbol);
        return symbol;
    }


    // ---------------------------------------------------------------
    // Check whether two symbols are equivalent for resolution.
    // ---------------------------------------------------------------
    bool SymbolsMatch(
        const string configured,
        const string broker_symbol
    )
    {
        string requested = NormalizeSymbol(configured);
        string available = NormalizeSymbol(broker_symbol);

        if(requested == available)
            return true;

        return false;
    }


    // ---------------------------------------------------------------
    // Attempt to resolve a configured symbol against all terminal
    // symbols.
    //
    // This supports common broker naming conventions:
    //
    // EURUSD
    // EURUSDm
    // mEURUSD
    // EURUSD.a
    // EURUSDm.a
    //
    // Exact matches always take priority.
    // ---------------------------------------------------------------
    string ResolveBrokerSymbol(const string configured_symbol)
    {
        if(configured_symbol == "")
            return "";
        

        // -----------------------------------------------------------
        // 1. Exact match.
        // -----------------------------------------------------------
        if(SymbolSelect(configured_symbol, true))
        {
            return configured_symbol;
        }


        // -----------------------------------------------------------
        // 2. Search all symbols.
        // -----------------------------------------------------------
        int total_symbols = SymbolsTotal(false);

        string requested =
            NormalizeSymbol(configured_symbol);


        // -----------------------------------------------------------
        // First pass:
        // Find a symbol beginning with the configured symbol.
        //
        // Example:
        // EURUSD -> EURUSDm
        // XAUUSD -> XAUUSDm
        // -----------------------------------------------------------
        for(int i = 0; i < total_symbols; i++)
        {
            string candidate =
                SymbolName(i, false);

            if(candidate == "")
                continue;

            string normalized_candidate =
                NormalizeSymbol(candidate);

            if(StringFind(
                   normalized_candidate,
                   requested
               ) == 0)
            {
                if(SymbolSelect(candidate, true))
                    return candidate;
            }
        }


        // -----------------------------------------------------------
        // Third pass:
        // Look for the configured symbol at the end.
        //
        // Example:
        // mEURUSD
        // -----------------------------------------------------------
        for(int i = 0; i < total_symbols; i++)
        {
            string candidate =
                SymbolName(i, false);

            if(candidate == "")
                continue;

            string normalized_candidate =
                NormalizeSymbol(candidate);

            int position =
                StringFind(
                    normalized_candidate,
                    requested
                );

            if(position >= 0)
            {
                int candidate_length =
                    StringLen(normalized_candidate);

                int requested_length =
                    StringLen(requested);

                if(position +
                   requested_length ==
                   candidate_length)
                {
                    if(SymbolSelect(candidate, true))
                        return candidate;
                }
            }
        }


        // -----------------------------------------------------------
        // No suitable broker symbol found.
        // -----------------------------------------------------------
        return "";
    }


    // ---------------------------------------------------------------
    // Resolve every configured symbol.
    // ---------------------------------------------------------------
    void ResolveUniverse()
    {
        int count = ArraySize(m_symbols);

        for(int i = 0; i < count; i++)
        {
            string configured =
                m_symbols[i].configured_name;

            string resolved =
                ResolveBrokerSymbol(configured);


            if(resolved != "")
            {
                m_symbols[i].name = resolved;
                m_symbols[i].available = true;

                m_logger.Log(
                    LOG_LEVEL_INFO,
                    "SymbolUniverse",
                    "SYMBOL_READY",
                    StringFormat(
                        "%s -> %s selected and available.",
                        configured,
                        resolved
                    )
                );
            }
            else
            {
                m_symbols[i].name = configured;
                m_symbols[i].available = false;

                m_logger.Log(
                    LOG_LEVEL_WARNING,
                    "SymbolUniverse",
                    "SYMBOL_UNAVAILABLE",
                    StringFormat(
                        "%s not found on broker.",
                        configured
                    )
                );
            }
        }
    }


public:

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------
    CSymbolUniverseManager(CLogger* logger)
        : m_logger(logger)
    {
        ArrayResize(m_symbols, 0);
    }


    // ---------------------------------------------------------------
    // Initialize configured universe.
    // ---------------------------------------------------------------
    void Initialize(
        const string &configured_symbols[]
    )
    {
        int size =
            ArraySize(configured_symbols);

        ArrayResize(
            m_symbols,
            size
        );

        for(int i = 0; i < size; i++)
        {
            m_symbols[i].configured_name =
                configured_symbols[i];

            // Initially use configured name.
            // ResolveUniverse() will replace it with
            // the broker-specific name if necessary.
            m_symbols[i].name =
                configured_symbols[i];

            m_symbols[i].mode =
                SYMBOL_MODE_WATCH;

            m_symbols[i].available =
                false;
        }
    }


    // ---------------------------------------------------------------
    // Validate and resolve the complete universe.
    // ---------------------------------------------------------------
    void ValidateUniverse()
    {
        ResolveUniverse();
    }


    // ---------------------------------------------------------------
    // Return number of configured symbols.
    // ---------------------------------------------------------------
    int GetSymbolCount()
    {
        return ArraySize(m_symbols);
    }


    // ---------------------------------------------------------------
    // Return symbol information.
    // ---------------------------------------------------------------
    SSymbolInfo GetSymbol(
        const int index
    )
    {
        SSymbolInfo empty_info;

        empty_info.configured_name = "";
        empty_info.name = "";
        empty_info.available = false;
        empty_info.mode = SYMBOL_MODE_DISABLED;


        if(index < 0 ||
           index >= ArraySize(m_symbols))
        {
            return empty_info;
        }

        return m_symbols[index];
    }


    // ---------------------------------------------------------------
    // Return actual broker symbol.
    // ---------------------------------------------------------------
    string GetBrokerSymbol(
        const int index
    )
    {
        if(index < 0 ||
           index >= ArraySize(m_symbols))
        {
            return "";
        }

        return m_symbols[index].name;
    }


    // ---------------------------------------------------------------
    // Return configured/base symbol.
    // ---------------------------------------------------------------
    string GetConfiguredSymbol(
        const int index
    )
    {
        if(index < 0 ||
           index >= ArraySize(m_symbols))
        {
            return "";
        }

        return m_symbols[index].configured_name;
    }


    // ---------------------------------------------------------------
    // Check availability.
    // ---------------------------------------------------------------
    bool IsAvailable(
        const int index
    )
    {
        if(index < 0 ||
           index >= ArraySize(m_symbols))
        {
            return false;
        }

        return m_symbols[index].available;
    }


    // ---------------------------------------------------------------
    // Count available symbols.
    // ---------------------------------------------------------------
    int GetAvailableCount()
    {
        int available = 0;

        for(int i = 0;
            i < ArraySize(m_symbols);
            i++)
        {
            if(m_symbols[i].available)
                available++;
        }

        return available;
    }
};

#endif // __ATG_SYMBOL_UNIVERSE_MANAGER_MQH__