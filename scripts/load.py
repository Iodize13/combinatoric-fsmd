#!/usr/bin/env python3
"""Send a program to the Nexys A7 CPU board over its USB-UART (board/uart_loader.vhd).

    scripts/load.py PROG [--tty /dev/ttyUSB1] [--baud 115200]
    scripts/load.py PROG --dry-run FRAME    write the frame to FRAME, open no port

PROG is a .bin of big-endian words, or a .s assembled first with
'customasm asm/cpu.asm PROG -f binary'. The frame is 0xA5, the program padded to 256 words
(1024 bytes), then the sum of those bytes mod 256. The board answers 'K' and restarts the
CPU at pc 0, or 'E' and keeps it held. Exit status 1 on 'E', on no reply, or on a bad PROG.
"""
import argparse
import os
import select
import subprocess
import sys
import tempfile
import termios
import time
import tty

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORDS = 256
START = 0xA5


def program_bytes(path):
    if path.endswith(".s"):
        with tempfile.TemporaryDirectory() as tmp:
            out = os.path.join(tmp, "prog.bin")
            subprocess.run(["customasm", "asm/cpu.asm", os.path.abspath(path),
                            "-f", "binary", "-o", out], cwd=ROOT, check=True)
            with open(out, "rb") as f:
                return f.read()
    with open(path, "rb") as f:
        return f.read()


def frame(prog):
    if len(prog) % 4:
        raise ValueError(f"{len(prog)} bytes is not a whole number of words")
    if len(prog) > 4 * WORDS:
        raise ValueError(f"{len(prog) // 4} words; the instruction memory holds {WORDS}")
    data = prog.ljust(4 * WORDS, b"\0")
    return bytes([START]) + data + bytes([sum(data) % 256])


def send(tty_path, baud, payload, timeout):
    fd = os.open(tty_path, os.O_RDWR | os.O_NOCTTY)
    try:
        tty.setraw(fd)
        attr = termios.tcgetattr(fd)
        speed = getattr(termios, f"B{baud}")
        attr[4] = attr[5] = speed
        attr[2] = (attr[2] & ~(termios.CSTOPB | termios.PARENB)) | termios.CLOCAL | termios.CREAD
        termios.tcsetattr(fd, termios.TCSANOW, attr)
        termios.tcflush(fd, termios.TCIOFLUSH)
        os.write(fd, payload)
        termios.tcdrain(fd)
        # the CPU is held from the 0xA5 on, so anything already received is its old output
        termios.tcflush(fd, termios.TCIFLUSH)
        deadline = time.monotonic() + timeout
        while (left := deadline - time.monotonic()) > 0:
            if select.select([fd], [], [], left)[0]:
                return os.read(fd, 1)
        return b""
    finally:
        os.close(fd)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("prog")
    ap.add_argument("--tty", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--timeout", type=float, default=2.0, help="seconds to wait for the reply")
    ap.add_argument("--dry-run", metavar="FRAME", help="write the frame to FRAME instead")
    args = ap.parse_args()
    if not hasattr(termios, f"B{args.baud}"):
        ap.error(f"unsupported baud rate {args.baud}")

    try:
        payload = frame(program_bytes(args.prog))
    except (OSError, ValueError, subprocess.CalledProcessError) as e:
        sys.exit(f"load.py: {args.prog}: {e}")

    if args.dry_run:
        with open(args.dry_run, "wb") as f:
            f.write(payload)
        print(f"wrote {len(payload)} bytes to {args.dry_run}, checksum 0x{payload[-1]:02X}")
        return

    try:
        reply = send(args.tty, args.baud, payload, args.timeout)
    except OSError as e:
        sys.exit(f"load.py: {args.tty}: {e}")
    if reply == b"K":
        print(f"K: loaded {args.prog}, CPU restarted")
    elif reply == b"E":
        sys.exit("E: the board rejected the frame (checksum or timeout); CPU held")
    elif reply:
        sys.exit(f"unexpected reply {reply!r}")
    else:
        sys.exit(f"no reply within {args.timeout} s on {args.tty}")


if __name__ == "__main__":
    main()
