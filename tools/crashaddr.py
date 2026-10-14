#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Erez Yaary
"""Put function names to the offsets in a CRASH.LOG.

    crashaddr.py CRASH.LOG [build/mail.elf]

Every "EMail+$1A2B4" and "+$1A2B4" gets the function it falls in, from
the ELF file of the same build: check out the version the report names
(the commit that set VERSION to it), run make, and point this at its
build/mail.elf. The offsets are from the start of the program's text,
which is where the ELF file starts too.
"""
import bisect
import re
import subprocess
import sys

log = sys.argv[1]
elf = sys.argv[2] if len(sys.argv) > 2 else "build/mail.elf"
nm = subprocess.run(["m68k-linux-gnu-nm", "-n", elf], capture_output=True, text=True, check=True)
syms = []
for line in nm.stdout.splitlines():
    p = line.split()
    if len(p) == 3 and p[1] in "tTwW":
        syms.append((int(p[0], 16), p[2]))
addrs = [a for a, _ in syms]


def name(off):
    i = bisect.bisect_right(addrs, off) - 1
    return "%s+$%X" % (syms[i][1], off - syms[i][0]) if i >= 0 else "?"


for line in open(log, encoding="latin-1"):
    line = line.rstrip("\r\n")
    print(re.sub(r"(EMail)?\+\$([0-9A-F]{6})",
                 lambda m: "%s [%s]" % (m.group(0), name(int(m.group(2), 16))), line))
