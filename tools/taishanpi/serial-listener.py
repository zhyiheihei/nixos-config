#!/usr/bin/env python3
"""Raw serial listener for Taishan Pi debug UART (1500000 baud)."""
import os, sys, termios, select, time

dev = "/dev/cu.usbmodem57920206431"
out = "/tmp/taishanpi-boot.log"

fd = os.open(dev, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
attrs = termios.tcgetattr(fd)
# Raw 8N1
attrs[0] = 0  # iflag
attrs[1] = 0  # oflag
attrs[2] = termios.CS8 | termios.CREAD  # cflag
attrs[3] = 0  # lflag
# macOS: ospeed/ispeed fields accept the raw baud number directly.
attrs[4] = 1500000
attrs[5] = 1500000
termios.tcsetattr(fd, termios.TCSANOW, attrs)

with open(out, "ab", buffering=0) as log:
    sys.stderr.write(f"listening {dev} @1500000 -> {out}\n")
    sys.stderr.flush()
    while True:
        r, _, _ = select.select([fd], [], [], 1.0)
        if fd in r:
            try:
                data = os.read(fd, 4096)
                if data:
                    log.write(data)
            except BlockingIOError:
                pass
        time.sleep(0.01)
