#!/usr/bin/env python3
"""Run tio on a pty so it stays in interactive mode and keeps listening.

tio exits immediately when stdin is not a tty; pty.fork() gives it a real
pseudo-terminal, so it runs forever and writes the serial log via --log-file.
"""
import os, pty, sys, time

dev = "/dev/cu.usbmodem57920206431"
logfile = "/tmp/taishanpi-boot.log"

pid, master = pty.fork()
if pid == 0:
    os.execvp("tio", ["tio", dev, "-b", "1500000", "-L", "--log-file", logfile])
    os._exit(1)

sys.stderr.write(f"tio running on pty, pid={pid}, log={logfile}\n")
sys.stderr.flush()
# Drain the pty master so tio's stdout never blocks; also forward a marker.
while True:
    try:
        data = os.read(master, 4096)
        if not data:
            break
    except OSError:
        break
    time.sleep(0.01)
os.waitpid(pid, 0)
