#!/usr/bin/env python3
"""Send commands to the tio pty (the running tio-pty.py owns it)."""
import os, sys, time, glob

# Find the pty master: tio-pty.py keeps master fd in its process.
# Simplest: write to the tty device directly is blocked (tio owns it).
# tio reads stdin from the pty slave; the master is held by tio-pty.py.
# We instead send via the tio process stdin which is the pty slave => write
# to the slave path. Find it via lsof or just use the device itself (tio
# holds O_RDWR so writes to /dev/cu.* from another fd are allowed on macOS).

dev = "/dev/cu.usbmodem57920206431"
cmd = (sys.argv[1] + "\r").encode()
with open(dev, "ab", buffering=0) as f:
    f.write(cmd)
    f.flush()
print(f"sent: {sys.argv[1]!r}")
