#!/usr/bin/env python3
"""Interactive serial login: send root, wait for password prompt, send password."""
import getpass
import os
import time

dev = "/dev/cu.usbmodem57920206431"
log = "/tmp/taishanpi-boot.log"
f = open(dev, "ab", buffering=0)

def send(s):
    f.write(s.encode())
    f.flush()

def wait_for(needle, timeout=15):
    end = time.time() + timeout
    while time.time() < end:
        try:
            data = open(log, "rb").read()
        except OSError:
            data = b""
        if needle.encode() in data:
            return True
        time.sleep(0.3)
    return False

# Reset to fresh login prompt
send("\x03")
time.sleep(0.5)
send("\r")
time.sleep(1.5)
password = os.environ.get("TAISHANPI_ROOT_PASSWORD")
if password is None:
    password = getpass.getpass("Taishan Pi root password: ")

# Login
send("root")
time.sleep(0.5)
send("\r")
# Wait for password prompt (Chinese locale "密码：" or English "Password:")
if wait_for("密码") or wait_for("assword"):
    print("password prompt seen, sending password")
    time.sleep(0.5)
    send(password)
    time.sleep(0.3)
    send("\r")
    print("password sent")
else:
    print("WARNING: password prompt not seen within timeout")
f.close()
