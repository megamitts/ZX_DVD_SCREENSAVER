#!/usr/bin/env python3
"""Wrap a raw Z80 binary in a ZX Spectrum .tap with a BASIC auto-loader.

Usage: make_tap.py code.bin out.tap [name] [load_address]

Tape layout (what the ROM tape loader expects):
  1. Program header   (autostarts at line 10)
  2. BASIC loader:    10 CLEAR 32767: LOAD "" CODE: RANDOMIZE USR 32768
  3. Code header
  4. Code data
"""
import struct
import sys


def block(flag, payload):
    """TAP block: 2-byte length, flag, payload, XOR checksum."""
    body = bytes([flag]) + payload
    checksum = 0
    for b in body:
        checksum ^= b
    body += bytes([checksum])
    return struct.pack("<H", len(body)) + body


def header(kind, name, length, param1, param2):
    name = name.encode("ascii")[:10].ljust(10, b" ")
    return block(0x00, bytes([kind]) + name + struct.pack("<HHH", length, param1, param2))


def number(n):
    """A number literal as the ROM stores it: ASCII digits + hidden 5-byte value."""
    return str(n).encode("ascii") + b"\x0e\x00\x00" + struct.pack("<H", n) + b"\x00"


def basic_loader(clear_addr, run_addr):
    # Tokens: CLEAR=FD  LOAD=EF  CODE=AF  RANDOMIZE=F9  USR=C0
    line = (
        b"\xfd" + number(clear_addr)          # CLEAR 32767
        + b":\xef\"\"\xaf"                    # : LOAD "" CODE
        + b":\xf9\xc0" + number(run_addr)     # : RANDOMIZE USR 32768
        + b"\x0d"                             # ENTER
    )
    return struct.pack(">H", 10) + struct.pack("<H", len(line)) + line


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    code = open(sys.argv[1], "rb").read()
    out = sys.argv[2]
    name = sys.argv[3] if len(sys.argv) > 3 else "HelloWorld"
    addr = int(sys.argv[4], 0) if len(sys.argv) > 4 else 32768

    prog = basic_loader(addr - 1, addr)

    tap = b"".join([
        header(0, name, len(prog), 10, len(prog)),   # Program, autostart line 10
        block(0xFF, prog),
        header(3, name, len(code), addr, 32768),     # Code, start address
        block(0xFF, code),
    ])
    open(out, "wb").write(tap)
    print(f"{out}: {len(tap)} bytes (BASIC loader {len(prog)} bytes, code {len(code)} bytes at {addr})")


if __name__ == "__main__":
    main()
