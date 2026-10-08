# run_live_monitor.py - Persistent Monitor for NeuroPip
import time
import os
import sys
import subprocess

config = os.environ.get("MT5_STARTUP_INI", os.path.join(TERM_DIR, "config", "startup.ini"))
exe = r"C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe"
log_dir = os.environ.get("MT5_LOG_DIR", os.path.join(TERM_DIR, "MQL5", "Logs"))

def get_running_mt5_pids():
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

today_str = time.strftime("%Y%m%d")
log_path = os.path.join(log_dir, f"{today_str}.log")
last_pos = os.path.getsize(log_path) if os.path.exists(log_path) else 0

print("=== NeuroPip - Live Forward Monitor ===")
pids = get_running_mt5_pids()
if pids:
    print(f"MT5 terminal64 is ALREADY running with PID(s): {pids}")
else:
    print(f"Launching MT5 terminal64 via Windows Shell...")
    os.startfile(exe, "open", f'/config:"{config}"')
    time.sleep(3)
    pids = get_running_mt5_pids()
    print(f"MT5 terminal64 launched successfully with PID(s): {pids}")

print(f"Log path: {log_path} (initial offset: {last_pos})")
print("Monitoring live output (Ctrl+C to stop monitor without stopping MT5)...")

try:
    while True:
        time.sleep(2)
        pids = get_running_mt5_pids()
        if not pids:
            print("MT5 process is no longer running!")
            break

        if os.path.exists(log_path):
            cur_sz = os.path.getsize(log_path)
            if cur_sz > last_pos:
                with open(log_path, "rb") as f:
                    f.seek(last_pos)
                    chunk = f.read().decode("utf-16le", errors="ignore")
                    last_pos = cur_sz
                    for line in chunk.splitlines():
                        line_str = line.strip()
                        if line_str:
                            print(line_str)
        sys.stdout.flush()
except KeyboardInterrupt:
    print("\nMonitor stopped by user. NOTE: MT5 process remains RUNNING persistently in background.")
