#!/usr/bin/env python3
import json, psutil, socket, os, time
from datetime import datetime, timezone

OUT_DIR = "/var/log/vm_state"
os.makedirs(OUT_DIR, exist_ok=True)
OUT_FILE = os.path.join(OUT_DIR, "monitor.json")

def snapshot():
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    net  = psutil.net_io_counters()
    now = datetime.now(timezone.utc)
    return {
        # human-friendly ISO8601 timestamp with UTC 'Z'
        "ts": now.isoformat().replace("+00:00", "Z"),
        # numeric timestamp (milliseconds since epoch)
        "epoch_ms": int(time.time() * 1000),
        "host": socket.gethostname(),
        "cpu_percent": psutil.cpu_percent(interval=1),
        "mem_total": mem.total,
        "mem_used": mem.used,
        "mem_percent": mem.percent,
        "disk_total": disk.total,
        "disk_used": disk.used,
        "disk_percent": disk.percent,
        "net_bytes_sent": net.bytes_sent,
        "net_bytes_recv": net.bytes_recv,
        "event": "system_monitor"
    }

with open(OUT_FILE, "a") as f:
    f.write(json.dumps(snapshot()) + "\n")
