# runtime_supervisor.py - Phase 10 Persistent Runtime Supervisor for NeuroPip
import os
import sys
import time
import shutil
import subprocess

def find_terminal_dir():
    if "MT5_DATA_PATH" in os.environ:
        return os.environ["MT5_DATA_PATH"]
    base = os.path.join(os.environ.get("APPDATA", ""), "MetaQuotes", "Terminal")
    if os.path.exists(base):
        for item in os.listdir(base):
            candidate = os.path.join(base, item)
            if os.path.isdir(candidate) and (os.path.exists(os.path.join(candidate, "origin.txt")) or os.path.exists(os.path.join(candidate, "MQL5"))):
                return candidate
    return os.path.join(base, "Default")

TERM_DIR = find_terminal_dir()
EXE = os.environ.get("MT5_EXE_PATH", r"C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe")
CONFIG = os.path.join(TERM_DIR, "config", "startup.ini")
DEFAULT_PROFILE = os.path.join(TERM_DIR, "MQL5", "Profiles", "Charts", "Default")
CHART_BACKUP = os.path.join(DEFAULT_PROFILE, "chart01.chr.bak")
CHART_TARGET = os.path.join(DEFAULT_PROFILE, "chart01.chr")
ORDER_WND = os.path.join(DEFAULT_PROFILE, "order.wnd")
LOGS_DIR = os.path.join(TERM_DIR, "Logs")
MQL_LOGS_DIR = os.path.join(TERM_DIR, "MQL5", "Logs")
SIMULATION_DIR = os.path.join(TERM_DIR, "MQL5", "Files", "ATG_Simulation")
SUPERVISOR_LOG = os.environ.get("SUPERVISOR_LOG", "supervisor.log")

def log_supervisor(msg: str):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    try:
        with open(SUPERVISOR_LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass

def get_mt5_pids():
    try:
        out = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", "Get-Process terminal64 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id"],
            text=True
        ).strip()
        if out:
            return [int(p.strip()) for p in out.splitlines() if p.strip().isdigit()]
    except Exception:
        pass
    return []

def restore_chart_and_profile():
    os.makedirs(DEFAULT_PROFILE, exist_ok=True)
    if os.path.exists(CHART_BACKUP):
        shutil.copyfile(CHART_BACKUP, CHART_TARGET)
    with open(ORDER_WND, "w", encoding="utf-8") as f:
        f.write("chart01.chr\n")

def get_ea_status():
    today_str = time.strftime("%Y%m%d")
    term_log = os.path.join(LOGS_DIR, f"{today_str}.log")
    mql_log = os.path.join(MQL_LOGS_DIR, f"{today_str}.log")

    pids = get_mt5_pids()
    if not pids:
        return False, None, "MT5 process terminal64.exe is NOT running"

    # Inspect terminal log for expert load / remove events
    last_event = None
    if os.path.exists(term_log):
        with open(term_log, "r", encoding="utf-16le", errors="ignore") as f:
            for line in f:
                if "NeuroPip_EA" in line:
                    last_event = line.strip()

    if not last_event or "removed" in last_event or "failed with code" in last_event:
        return False, None, f"Terminal log indicates EA is detached: {last_event}"

    # Inspect MQL log for recent heartbeat / tick freshness
    if not os.path.exists(mql_log):
        return False, None, "MQL log does not exist"

    file_age = time.time() - os.path.getmtime(mql_log)
    if file_age > 45:
        return False, None, f"MQL log stale: last written {file_age:.1f}s ago (>45s threshold)"

    # Get last heartbeat
    last_heartbeat = None
    with open(mql_log, "rb") as f:
        f.seek(max(0, os.path.getsize(mql_log) - 16384))
        chunk = f.read().decode("utf-16le", errors="ignore")
        for line in chunk.splitlines():
            if "MARKET_HEARTBEAT" in line:
                last_heartbeat = line.strip()

    return True, last_heartbeat, f"EA is ACTIVE and attached (PID {pids[0]}, log age {file_age:.1f}s)"

def stop_mt5():
    pids = get_mt5_pids()
    if pids:
        log_supervisor(f"Stopping MT5 processes: {pids}")
        subprocess.run(["powershell", "-NoProfile", "-Command", "Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue"])
        time.sleep(2)

def launch_mt5():
    restore_chart_and_profile()
    log_supervisor("Launching MT5 via Task Scheduler (Launch_MT5_ATG)...")
    res = subprocess.run(["schtasks.exe", "/run", "/tn", "Launch_MT5_ATG"], capture_output=True, text=True)
    if "SUCCESS" not in res.stdout:
        # Fallback to direct shell execution
        log_supervisor(f"Scheduled task run returned: {res.stdout.strip()} - launching via start command...")
        bat = os.environ.get("MT5_LAUNCH_BAT", "Launch_NeuroPip.bat")
        subprocess.run(["cmd.exe", "/c", f'start "" "{bat}"'])
    time.sleep(3)

def recover_ea(timeout=45):
    log_supervisor("Initiating EA recovery cycle...")
    stop_mt5()
    launch_mt5()
    
    start_t = time.time()
    while time.time() - start_t < timeout:
        time.sleep(2)
        attached, hb, detail = get_ea_status()
        if attached:
            log_supervisor(f"Recovery successful! {detail}")
            return True
    log_supervisor("Recovery timed out waiting for EA to attach!")
    return False

def check_and_recover():
    attached, hb, detail = get_ea_status()
    log_supervisor(f"EA Status Check: {detail}")
    if not attached:
        log_supervisor("EA is DETACHED or missing! Triggering recovery...")
        return recover_ea()
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--recover":
        success = recover_ea()
        sys.exit(0 if success else 1)
    elif len(sys.argv) > 1 and sys.argv[1] == "--status":
        attached, hb, detail = get_ea_status()
        print(f"ATTACHED: {attached}")
        print(f"DETAIL: {detail}")
        if hb:
            print(f"HEARTBEAT: {hb}")
        sys.exit(0 if attached else 1)
    else:
        success = check_and_recover()
        sys.exit(0 if success else 1)
