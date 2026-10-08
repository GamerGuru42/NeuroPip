//+------------------------------------------------------------------+
//| PaperTradeStorage.mqh                                            |
//| NeuroPip - Phase 7                                      |
//| Durable Storage Engine for Active/Closed Paper Trades & Equity   |
//| MONITOR_ONLY - No execution capability                            |
//+------------------------------------------------------------------+
#ifndef ATG_PAPER_TRADE_STORAGE_MQH
#define ATG_PAPER_TRADE_STORAGE_MQH

#include "PersistenceTypes.mqh"
#include "../Diagnostics/Logger.mqh"
#include "../Analytics/ForwardEvidenceTypes.mqh"

// Header signatures
#define SCHEMA_HEADER_PREFIX     "# SCHEMA_VERSION: "
#define ACTIVE_TRADES_HEADER     "paper_trade_id,source_plan_id,strategy_id,symbol,direction,primary_timeframe,entry_time,exit_time,source_bar_time,holding_duration_sec,entry_price,stop_loss,take_profit,exit_price,mae_points,mfe_points,volume,risk_money,equity_at_entry,risk_percent,planned_rr,gross_pnl,simulated_costs,net_pnl,realized_r,status,exit_reason,strategy_confidence,strategy_quality,regime,candidate_only,dataset_class,data_quality,quality_warning_reason,config_fingerprint,cohort_id,entry_spread_points"
#define CLOSED_TRADES_HEADER     "paper_trade_id,source_plan_id,strategy_id,symbol,direction,primary_timeframe,entry_time,exit_time,source_bar_time,holding_duration_sec,entry_price,stop_loss,take_profit,exit_price,mae_points,mfe_points,volume,risk_money,equity_at_entry,risk_percent,planned_rr,gross_pnl,simulated_costs,net_pnl,realized_r,status,exit_reason,strategy_confidence,strategy_quality,regime,candidate_only,dataset_class,data_quality,quality_warning_reason,config_fingerprint,cohort_id,entry_spread_points"
#define EQUITY_HISTORY_HEADER    "timestamp,event_type,trade_id,equity,balance,peak_equity,drawdown,drawdown_pct,realized_pnl,realized_r"
#define FORWARD_SNAPSHOTS_HEADER "period_type,period_key,timestamp,trades_closed,wins,losses,win_rate,net_pnl,avg_r,expectancy,current_equity,max_drawdown,max_drawdown_pct,quality_warnings,quality_invalids,cohort_id,config_fingerprint"

//+------------------------------------------------------------------+
//| CPaperTradeStorage                                               |
//+------------------------------------------------------------------+
class CPaperTradeStorage
{
private:
   CLogger*             m_logger;
   bool                 m_enabled;
   int                  m_schema_version;
   string               m_base_folder;
   bool                 m_audit_enabled;
   ENUM_STORAGE_STATUS  m_status;

   string GetPath(const string filename) const
   {
      if(m_base_folder == "")
         return filename;
      return m_base_folder + "\\" + filename;
   }

public:
   CPaperTradeStorage(CLogger* logger = NULL,
                      const string base_folder = "ATG_Simulation",
                      int schema_version = ATG_STORAGE_SCHEMA_VERSION,
                      bool enabled = true,
                      bool audit_enabled = true)
      : m_logger(logger),
        m_enabled(enabled),
        m_schema_version(schema_version),
        m_base_folder(base_folder),
        m_audit_enabled(audit_enabled),
        m_status(STORAGE_STATUS_UNINITIALIZED)
   {
   }

   // Configuration
   void SetLogger(CLogger* logger)                { m_logger = logger; }
   void SetEnabled(bool enabled)                  { m_enabled = enabled; }
   bool IsEnabled() const                         { return m_enabled; }
   void SetBaseFolder(const string folder)        { m_base_folder = folder; }
   string GetBaseFolder() const                   { return m_base_folder; }
   void SetSchemaVersion(int ver)                 { m_schema_version = ver; }
   int  GetSchemaVersion() const                  { return m_schema_version; }
   void SetAuditEnabled(bool audit)               { m_audit_enabled = audit; }
   ENUM_STORAGE_STATUS GetStatus() const          { return m_status; }

   //+----------------------------------------------------------------+
   //| Initialize storage directory and base files                    |
   //+----------------------------------------------------------------+
   bool Initialize()
   {
      if(!m_enabled)
      {
         m_status = STORAGE_STATUS_DISABLED;
         if(m_logger != NULL)
            m_logger.Log(LOG_LEVEL_INFO, "Storage", "PERSISTENCE_DISABLED", "Paper trade persistence is disabled by config.");
         return true;
      }

      // Ensure directory exists in MQL5\Files
      if(m_base_folder != "")
      {
         ResetLastError();
         FolderCreate(m_base_folder);
      }

      // Ensure active_trades.csv exists
      string active_path = GetPath("active_trades.csv");
      if(!FileIsExist(active_path))
      {
         int h = FileOpen(active_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
            FileWriteString(h, StringFormat("%s\n", ACTIVE_TRADES_HEADER));
            FileClose(h);
         }
      }

      // Ensure closed_trades.csv exists
      string closed_path = GetPath("closed_trades.csv");
      if(!FileIsExist(closed_path))
      {
         int h = FileOpen(closed_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
            FileWriteString(h, StringFormat("%s\n", CLOSED_TRADES_HEADER));
            FileClose(h);
         }
      }

      // Ensure equity_history.csv exists
      string equity_path = GetPath("equity_history.csv");
      if(!FileIsExist(equity_path))
      {
         int h = FileOpen(equity_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
            FileWriteString(h, StringFormat("%s\n", EQUITY_HISTORY_HEADER));
            FileClose(h);
         }
      }

      // Ensure forward_snapshots.csv exists
      string snap_path = GetPath("forward_snapshots.csv");
      if(!FileIsExist(snap_path))
      {
         int h = FileOpen(snap_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
            FileWriteString(h, StringFormat("%s\n", FORWARD_SNAPSHOTS_HEADER));
            FileClose(h);
         }
      }

      // Ensure forward_milestone_snapshots.csv exists
      string ms_path = GetPath("forward_milestone_snapshots.csv");
      if(!FileIsExist(ms_path))
      {
         int h = FileOpen(ms_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
            FileWriteString(h, StringFormat("%s\n", FORWARD_MILESTONE_SNAPSHOTS_HEADER));
            FileClose(h);
         }
      }

      // Ensure daily_snapshots.csv exists
      string daily_path = GetPath("daily_snapshots.csv");
      if(!FileIsExist(daily_path))
      {
         int h = FileOpen(daily_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
            FileWriteString(h, StringFormat("%s\n", FORWARD_DAILY_SNAPSHOTS_HEADER));
            FileClose(h);
         }
      }

      // Ensure weekly_snapshots.csv exists
      string weekly_path = GetPath("weekly_snapshots.csv");
      if(!FileIsExist(weekly_path))
      {
         int h = FileOpen(weekly_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
            FileWriteString(h, StringFormat("%s\n", FORWARD_WEEKLY_SNAPSHOTS_HEADER));
            FileClose(h);
         }
      }

      // Ensure monthly_snapshots.csv exists
      string monthly_path = GetPath("monthly_snapshots.csv");
      if(!FileIsExist(monthly_path))
      {
         int h = FileOpen(monthly_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
            FileWriteString(h, StringFormat("%s\n", FORWARD_MONTHLY_SNAPSHOTS_HEADER));
            FileClose(h);
         }
      }

      m_status = STORAGE_STATUS_READY;
      AppendAudit(AUDIT_PERSISTENCE_LOAD, 0, "", "Persistence store initialized successfully.");

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "Storage", "PERSISTENCE_READY",
            StringFormat("Persistence Engine ready. Folder=%s | SchemaVer=%d", m_base_folder, m_schema_version));
      }

      return true;
   }

   //+----------------------------------------------------------------+
   //| Save active paper trades atomically                            |
   //+----------------------------------------------------------------+
   bool SaveActiveTrades(const SPaperTrade &trades[])
   {
      if(!m_enabled) return true;

      string tmp_path = GetPath("active_trades.tmp");
      string final_path = GetPath("active_trades.csv");

      int h = FileOpen(tmp_path, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         AppendAudit(AUDIT_PERSISTENCE_ERROR, 0, "", "Failed to open active_trades.tmp for write.");
         if(m_logger != NULL)
            m_logger.Log(LOG_LEVEL_ERROR, "Storage", "PERSISTENCE_SAVE_ERROR", "Cannot open active_trades.tmp");
         return false;
      }

      // Write schema header and column header
      FileWriteString(h, StringFormat("%s%d\n", SCHEMA_HEADER_PREFIX, m_schema_version));
      FileWriteString(h, StringFormat("%s\n", ACTIVE_TRADES_HEADER));

      int count = ArraySize(trades);
      for(int i = 0; i < count; i++)
      {
         // Strictly require candidate_only == true
         if(trades[i].candidate_only && trades[i].paper_trade_id > 0)
         {
            FileWriteString(h, trades[i].ToCsv() + "\n");
         }
      }
      FileClose(h);

      // Copy tmp to final
      ResetLastError();
      FileDelete(final_path);
      if(!FileMove(tmp_path, 0, final_path, FILE_REWRITE))
      {
         // Fallback: copy content
         FileCopy(tmp_path, 0, final_path, FILE_REWRITE);
         FileDelete(tmp_path);
      }

      AppendAudit(AUDIT_PERSISTENCE_SAVE, 0, "", StringFormat("Saved %d active paper trades.", count));
      return true;
   }

   //+----------------------------------------------------------------+
   //| Load active paper trades with crash-resilient validation       |
   //+----------------------------------------------------------------+
   bool LoadActiveTrades(SPaperTrade &trades[], ulong &max_trade_id)
   {
      ArrayResize(trades, 0);
      if(!m_enabled) return true;

      string path = GetPath("active_trades.csv");
      if(!FileIsExist(path))
         return true;

      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         AppendAudit(AUDIT_PERSISTENCE_ERROR, 0, "", "Failed to open active_trades.csv for reading.");
         return false;
      }

      int recovered_count = 0;
      int rejected_count = 0;
      int line_num = 0;

      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);
         line_num++;

         if(line == "") continue;

         // Check schema version header
         if(StringFind(line, SCHEMA_HEADER_PREFIX) == 0)
         {
            string ver_str = StringSubstr(line, StringLen(SCHEMA_HEADER_PREFIX));
            int ver = (int)StringToInteger(ver_str);
            if(ver != m_schema_version)
            {
               AppendAudit(AUDIT_PERSISTENCE_ERROR, 0, "",
                  StringFormat("Schema version mismatch in active trades: expected %d, got %d", m_schema_version, ver));
               if(m_logger != NULL)
               {
                  m_logger.Log(LOG_LEVEL_WARNING, "Storage", "SCHEMA_MISMATCH",
                     StringFormat("Active trades schema mismatch (file: %d, engine: %d)", ver, m_schema_version));
               }
            }
            continue;
         }

         // Skip column header
         if(StringFind(line, "paper_trade_id") == 0)
            continue;

         // Parse trade record
         SPaperTrade t;
         t.Reset();
         if(!t.FromCsv(line))
         {
            rejected_count++;
            AppendAudit(AUDIT_RECOVERY_REJECTED, 0, "",
               StringFormat("Malformed active trade at line %d rejected.", line_num));
            continue;
         }

         // Verify candidate_only and open status
         if(!t.candidate_only || (t.status != PAPER_OPEN && t.status != PAPER_PENDING))
         {
            rejected_count++;
            AppendAudit(AUDIT_RECOVERY_REJECTED, t.paper_trade_id, t.symbol,
               "Invalid status or safety violation in active record.");
            continue;
         }

         // Deduplication check
         bool is_duplicate = false;
         for(int d = 0; d < ArraySize(trades); d++)
         {
            if(trades[d].paper_trade_id == t.paper_trade_id)
            {
               is_duplicate = true;
               break;
            }
         }
         if(is_duplicate)
         {
            rejected_count++;
            AppendAudit(AUDIT_RECOVERY_REJECTED, t.paper_trade_id, t.symbol, "Duplicate trade ID skipped.");
            continue;
         }

         // Append recovered trade
         int size = ArraySize(trades);
         ArrayResize(trades, size + 1);
         trades[size] = t;
         recovered_count++;

         if(t.paper_trade_id > max_trade_id)
            max_trade_id = t.paper_trade_id;
      }
      FileClose(h);

      AppendAudit(AUDIT_RECOVERY_SUCCESS, 0, "",
         StringFormat("Recovered %d active paper trades (%d rejected).", recovered_count, rejected_count));

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "Storage", "RECOVERY_COMPLETE",
            StringFormat("Active trades recovery complete: %d loaded, %d rejected.", recovered_count, rejected_count));
      }

      return true;
   }

   int LoadActiveTrades(SPaperTrade &trades[])
   {
      ulong max_id = 0;
      LoadActiveTrades(trades, max_id);
      return ArraySize(trades);
   }

   //+----------------------------------------------------------------+
   //| Append a single closed trade to durable history                |
   //+----------------------------------------------------------------+
   bool AppendClosedTrade(const SPaperTrade &trade)
   {
      if(!m_enabled) return true;

      // Absolute safety invariant
      if(!trade.candidate_only || trade.paper_trade_id == 0)
         return false;

      string path = GetPath("closed_trades.csv");
      int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         AppendAudit(AUDIT_PERSISTENCE_ERROR, trade.paper_trade_id, trade.symbol, "Cannot open closed_trades.csv for append.");
         return false;
      }

      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, trade.ToCsv() + "\n");
      FileClose(h);

      AppendAudit(AUDIT_PAPER_TRADE_CLOSED, trade.paper_trade_id, trade.symbol,
         StringFormat("Closed trade persisted | PnL=$%.2f (%.2fR) | %s", trade.net_pnl, trade.realized_r, trade.exit_reason));

      return true;
   }

   //+----------------------------------------------------------------+
   //| Load all closed trades from history                            |
   //+----------------------------------------------------------------+
   bool LoadClosedTrades(SPaperTrade &trades[], ulong &max_trade_id)
   {
      ArrayResize(trades, 0);
      if(!m_enabled) return true;

      string path = GetPath("closed_trades.csv");
      if(!FileIsExist(path))
         return true;

      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         AppendAudit(AUDIT_PERSISTENCE_ERROR, 0, "", "Cannot open closed_trades.csv for read.");
         return false;
      }

      int loaded_count = 0;
      int rejected_count = 0;

      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);

         if(line == "" || StringFind(line, "#") == 0 || StringFind(line, "paper_trade_id") == 0)
            continue;

         SPaperTrade t;
         t.Reset();
         if(!t.FromCsv(line))
         {
            rejected_count++;
            continue;
         }

         if(!t.candidate_only)
         {
            rejected_count++;
            continue;
         }

         // Deduplication check
         bool dup = false;
         for(int i = 0; i < ArraySize(trades); i++)
         {
            if(trades[i].paper_trade_id == t.paper_trade_id)
            {
               dup = true;
               break;
            }
         }
         if(dup) continue;

         int size = ArraySize(trades);
         ArrayResize(trades, size + 1);
         trades[size] = t;
         loaded_count++;

         if(t.paper_trade_id > max_trade_id)
            max_trade_id = t.paper_trade_id;
      }
      FileClose(h);

      if(m_logger != NULL)
      {
         m_logger.Log(LOG_LEVEL_INFO, "Storage", "CLOSED_HISTORY_LOADED",
            StringFormat("Loaded %d closed trades from history (%d rejected).", loaded_count, rejected_count));
      }

      return true;
   }

   int LoadClosedTrades(SPaperTrade &trades[])
   {
      ulong max_id = 0;
      LoadClosedTrades(trades, max_id);
      return ArraySize(trades);
   }

   //+----------------------------------------------------------------+
   //| Append an equity history point                                 |
   //+----------------------------------------------------------------+
   bool AppendEquityPoint(const SEquityPoint &pt)
   {
      if(!m_enabled) return true;

      string path = GetPath("equity_history.csv");
      int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;

      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, pt.ToCsv() + "\n");
      FileClose(h);

      return true;
   }

   //+----------------------------------------------------------------+
   //| Load equity history                                            |
   //+----------------------------------------------------------------+
   bool LoadEquityHistory(SEquityPoint &pts[])
   {
      ArrayResize(pts, 0);
      if(!m_enabled) return true;

      string path = GetPath("equity_history.csv");
      if(!FileIsExist(path)) return true;

      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;

      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);

         if(line == "" || StringFind(line, "#") == 0 || StringFind(line, "timestamp") == 0)
            continue;

         SEquityPoint pt;
         pt.Reset();
         if(pt.FromCsv(line))
         {
            int size = ArraySize(pts);
            ArrayResize(pts, size + 1);
            pts[size] = pt;
         }
      }
      FileClose(h);
      return true;
   }

   //+----------------------------------------------------------------+
   //| Append periodic forward evidence snapshot                      |
   //+----------------------------------------------------------------+
   bool AppendForwardSnapshot(const SForwardSnapshotRecord &rec)
   {
      if(!m_enabled) return true;

      string path = GetPath("forward_snapshots.csv");
      int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         AppendAudit(AUDIT_PERSISTENCE_ERROR, 0, "", "Cannot open forward_snapshots.csv for append.");
         return false;
      }

      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, rec.ToCsv() + "\n");
      FileClose(h);

      AppendAudit(AUDIT_FORWARD_SNAPSHOT_SAVED, 0, "",
         StringFormat("Snapshot %s (%s) saved | Closed=%d | NetPnL=$%.2f | Cohort=%s",
            rec.period_type, rec.period_key, rec.trades_closed, rec.net_pnl, rec.cohort_id));

      return true;
   }

   //+----------------------------------------------------------------+
   //| Load all forward snapshots from history                        |
   //+----------------------------------------------------------------+
   bool LoadForwardSnapshots(SForwardSnapshotRecord &records[])
   {
      ArrayResize(records, 0);
      if(!m_enabled) return true;

      string path = GetPath("forward_snapshots.csv");
      if(!FileIsExist(path))
         return true;

      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         AppendAudit(AUDIT_PERSISTENCE_ERROR, 0, "", "Cannot open forward_snapshots.csv for read.");
         return false;
      }

      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);

         if(line == "" || StringFind(line, "#") == 0 || StringFind(line, "period_type") == 0)
            continue;

         SForwardSnapshotRecord rec;
         rec.Reset();
         if(rec.FromCsv(line))
         {
            int size = ArraySize(records);
            ArrayResize(records, size + 1);
            records[size] = rec;
         }
      }
      FileClose(h);
      return true;
   }

   //+----------------------------------------------------------------+
   //| Append Phase 10 Milestone Snapshot                             |
   //+----------------------------------------------------------------+
   bool AppendMilestoneSnapshot(const SForwardMilestoneSnapshot &snap)
   {
      if(!m_enabled) return true;

      string path = GetPath("forward_milestone_snapshots.csv");
      int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         AppendAudit(AUDIT_PERSISTENCE_ERROR, 0, "", "Failed to open forward_milestone_snapshots.csv for append.");
         return false;
      }

      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, snap.ToCsv() + "\n");
      FileClose(h);
      return true;
   }

   bool LoadMilestoneSnapshots(SForwardMilestoneSnapshot &records[])
   {
      ArrayResize(records, 0);
      if(!m_enabled) return true;

      string path = GetPath("forward_milestone_snapshots.csv");
      if(!FileIsExist(path)) return true;

      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;

      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);

         if(line == "" || StringFind(line, "#") == 0 || StringFind(line, "milestone_name") == 0)
            continue;

         SForwardMilestoneSnapshot rec;
         rec.Reset();
         if(rec.FromCsv(line))
         {
            int size = ArraySize(records);
            ArrayResize(records, size + 1);
            records[size] = rec;
         }
      }
      FileClose(h);
      return true;
   }

   //+----------------------------------------------------------------+
   //| Append / Load Daily Snapshots                                  |
   //+----------------------------------------------------------------+
   bool AppendDailySnapshot(const SForwardDailySnapshot &snap)
   {
      if(!m_enabled) return true;
      string path = GetPath("daily_snapshots.csv");
      int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, snap.ToCsv() + "\n");
      FileClose(h);
      return true;
   }

   bool LoadDailySnapshots(SForwardDailySnapshot &records[])
   {
      ArrayResize(records, 0);
      if(!m_enabled) return true;
      string path = GetPath("daily_snapshots.csv");
      if(!FileIsExist(path)) return true;
      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;

      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);
         if(line == "" || StringFind(line, "#") == 0 || StringFind(line, "date_key") == 0)
            continue;
         SForwardDailySnapshot rec;
         rec.Reset();
         if(rec.FromCsv(line))
         {
            int size = ArraySize(records);
            ArrayResize(records, size + 1);
            records[size] = rec;
         }
      }
      FileClose(h);
      return true;
   }

   //+----------------------------------------------------------------+
   //| Append / Load Weekly Snapshots                                 |
   //+----------------------------------------------------------------+
   bool AppendWeeklySnapshot(const SForwardWeeklySnapshot &snap)
   {
      if(!m_enabled) return true;
      string path = GetPath("weekly_snapshots.csv");
      int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, snap.ToCsv() + "\n");
      FileClose(h);
      return true;
   }

   bool LoadWeeklySnapshots(SForwardWeeklySnapshot &records[])
   {
      ArrayResize(records, 0);
      if(!m_enabled) return true;
      string path = GetPath("weekly_snapshots.csv");
      if(!FileIsExist(path)) return true;
      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;

      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);
         if(line == "" || StringFind(line, "#") == 0 || StringFind(line, "week_key") == 0)
            continue;
         SForwardWeeklySnapshot rec;
         rec.Reset();
         if(rec.FromCsv(line))
         {
            int size = ArraySize(records);
            ArrayResize(records, size + 1);
            records[size] = rec;
         }
      }
      FileClose(h);
      return true;
   }

   //+----------------------------------------------------------------+
   //| Append / Load Monthly Snapshots                                |
   //+----------------------------------------------------------------+
   bool AppendMonthlySnapshot(const SForwardMonthlySnapshot &snap)
   {
      if(!m_enabled) return true;
      string path = GetPath("monthly_snapshots.csv");
      int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, snap.ToCsv() + "\n");
      FileClose(h);
      return true;
   }

   bool LoadMonthlySnapshots(SForwardMonthlySnapshot &records[])
   {
      ArrayResize(records, 0);
      if(!m_enabled) return true;
      string path = GetPath("monthly_snapshots.csv");
      if(!FileIsExist(path)) return true;
      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h == INVALID_HANDLE) return false;

      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);
         if(line == "" || StringFind(line, "#") == 0 || StringFind(line, "month_key") == 0)
            continue;
         SForwardMonthlySnapshot rec;
         rec.Reset();
         if(rec.FromCsv(line))
         {
            int size = ArraySize(records);
            ArrayResize(records, size + 1);
            records[size] = rec;
         }
      }
      FileClose(h);
      return true;
   }

   //+----------------------------------------------------------------+
   //| Append audit log event                                         |
   //+----------------------------------------------------------------+
   void AppendAudit(ENUM_AUDIT_EVENT_TYPE evt, ulong trade_id, const string symbol, const string details)
   {
      if(!m_audit_enabled) return;

      SAuditRecord rec;
      rec.timestamp  = TimeCurrent();
      rec.event_type = evt;
      rec.trade_id   = trade_id;
      rec.symbol     = symbol;
      rec.details    = details;

      string line = rec.Format();

      if(m_enabled)
      {
         string path = GetPath("audit_trail.log");
         int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(h != INVALID_HANDLE)
         {
            FileSeek(h, 0, SEEK_END);
            FileWriteString(h, line + "\n");
            FileClose(h);
         }
      }

      if(m_logger != NULL)
      {
         ENUM_LOG_LEVEL lvl = (evt == AUDIT_PERSISTENCE_ERROR || evt == AUDIT_RECOVERY_REJECTED || evt == AUDIT_CONFIG_TAMPERING_DETECTED)
            ? LOG_LEVEL_WARNING : LOG_LEVEL_INFO;
         m_logger.Log(lvl, "AuditTrail", AuditEventToString(evt),
            StringFormat("TradeID=%I64u | %s | %s", trade_id, symbol == "" ? "N/A" : symbol, details));
      }
   }
};

#endif
