import subprocess
import time
import os
import sys

config = os.environ.get("MT5_STARTUP_INI", os.path.join(TERM_DIR, "config", "startup.ini"))
exe = r"C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe"
log_dir = os.environ.get("MT5_LOG_DIR", os.path.join(TERM_DIR, "MQL5", "Logs"))

def get_running_mt5_info():
    try:
        ps_cmd = 'Get-Process terminal64 -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, MainWindowTitle, MainWindowHandle | ConvertTo-Json'
        out = subprocess.check_output(["powershell", "-NoProfile", "-Command", ps_cmd], text=True).strip()
        if out:
            import json
            data = json.loads(out)
            if isinstance(data, dict):
                return [data]
            elif isinstance(data, list):
                return data
    except Exception as e:
        pass
    return []

today_str = time.strftime("%Y%m%d")
log_path = os.path.join(log_dir, f"{today_str}.log")
last_pos = os.path.getsize(log_path) if os.path.exists(log_path) else 0

print("=== STEP 1: INITIAL PROCESS STATE CHECK ===")
initial_procs = get_running_mt5_info()
print(f"MT5 terminal64 processes before launch: {initial_procs}")

print("\n=== STEP 2: LAUNCHING MT5 DETACHED ===")
# Launch using cmd.exe /c start to guarantee a detached interactive GUI window
launch_cmd = f'start "" "{exe}" /config:"{config}"'
subprocess.run(["cmd.exe", "/c", launch_cmd], check=True)
print("Launch command executed via Windows Shell.")

print("\n=== STEP 3: WAITING FOR MT5 INITIALIZATION (15 seconds) ===")
time.sleep(15)

active_procs = get_running_mt5_info()
print(f"Active MT5 processes after launch: {active_procs}")
if not active_procs:
    print("ERROR: MT5 failed to launch or stay active!")
    sys.exit(1)

print("\n=== STEP 4: CAPTURING LOG OUTPUT SINCE LAUNCH ===")
captured_lines = []
if os.path.exists(log_path):
    cur_sz = os.path.getsize(log_path)
    if cur_sz > last_pos:
        with open(log_path, "rb") as f:
            f.seek(last_pos)
            chunk = f.read().decode("utf-16le", errors="ignore")
            for line in chunk.splitlines():
                line_str = line.strip()
                if line_str:
                    captured_lines.append(line_str)
                    print(f"  {line_str}")

print(f"\nTotal new log lines captured: {len(captured_lines)}")
print("Verification script is now EXITING. MT5 must remain running!")
