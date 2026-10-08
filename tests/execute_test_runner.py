import subprocess
import time
import os
import sys

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
config = os.environ.get("MT5_TEST_RUNNER_INI", os.path.join(TERM_DIR, "config", "test_runner.ini"))
exe = r"C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe"
log_dir = os.environ.get("MT5_LOG_DIR", os.path.join(TERM_DIR, "MQL5", "Logs"))

today_str = time.strftime("%Y%m%d")
log_path = os.path.join(log_dir, f"{today_str}.log")
last_pos = os.path.getsize(log_path) if os.path.exists(log_path) else 0

print(f"Starting MT5 with Master Test Runner Script...")
print(f"Log path: {log_path} (initial offset: {last_pos})")

proc = subprocess.Popen([exe, f"/config:{config}"])
print(f"MT5 Process started with PID: {proc.pid}")

start_time = time.time()
test_finished = False
success_found = False

try:
    while time.time() - start_time < 90:
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
                            print(line_str)
                            if "ALL SUITES (PHASES 3, 4, 5, 6, 7, 8, 9, 10) PASSED SUCCESSFULLY" in line_str:
                                success_found = True
                            if "TEST SUITE FAILURES DETECTED" in line_str:
                                test_finished = True
        if proc.poll() is not None:
            print(f"MT5 terminated with return code {proc.returncode}")
            test_finished = True
            break
        if success_found:
            print("Master test suite pass detected! Waiting for MT5 to exit...")
            time.sleep(3)
            break
finally:
    if proc.poll() is None:
        print("Terminating MT5 process...")
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()

if success_found:
    print("\nSUCCESS: All suites (Phases 3 through 10) passed 100%!")
    sys.exit(0)
else:
    print("\nFAILURE: Master test suite did not report full success.")
    sys.exit(1)
