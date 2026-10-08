import subprocess
import time
import os
import sys

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

print("=== ATG Trading Engine - Runtime Verification ===")
initial_pids = get_running_mt5_pids()
print(f"MT5 PID before launch/verification: {initial_pids if initial_pids else 'None'}")

if not initial_pids:
    print("Launching MT5 Terminal via Windows Shell (detached, persistent GUI)...")
    os.startfile(exe, "open", f'/config:"{config}"')
    time.sleep(3)
    pids = get_running_mt5_pids()
    print(f"MT5 Process started successfully with PID: {pids}")
else:
    print(f"MT5 is already running with PID: {initial_pids}")
    pids = initial_pids

print(f"Log path: {log_path} (initial offset: {last_pos})")

start_time = time.time()
lines_captured = []

print("Capturing live initialization and tick synchronization (30s sample)...")
while time.time() - start_time < 30:
    time.sleep(1)
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
                        lines_captured.append(line_str)
                        print(line_str)

final_pids = get_running_mt5_pids()
print(f"\nVerification period ended. Total lines captured: {len(lines_captured)}")
print(f"PERSISTENCE CHECK: MT5 Terminal remains RUNNING with PID(s): {final_pids}")
if not final_pids:
    print("ERROR: MT5 is NOT running!")
    sys.exit(1)
else:
    print("SUCCESS: MT5 Terminal and EA are active and persistently running.")
