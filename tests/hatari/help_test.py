#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 AERA | Erez Yaary
"""EMAIL.HYP in EHypView's latest release (the AERA guidelines, 1.2 and
4.3), as Erez reads it: the front page opens with its two pictures (the
banner and the main window), on a Falcon in 16 colours and on a TT in
black and white. Screenshots of the page, top to bottom, for people to
look at.

    help_test.py WORKDIR EMUTOS.IMG [vX.Y]   (make help first; EHypView's latest release, or that one)
"""
import os
import shutil
import sys
import time

import rig
from rig import K

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

work, tos = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
spec = "EHypView@" + sys.argv[3] if len(sys.argv) > 3 else "EHypView"
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
ehv = os.path.join(work, "ehypview")
tag = rig.release(spec, ehv, "EHYPVIEW.PRG")
checks = []


def check(what, good):
    checks.append(good)
    print("  %s   %s" % ("ok" if good else "FAIL", what))


def look(name, machine, extra):
    w = os.path.join(work, name)
    hd = os.path.join(w, "hd")
    os.makedirs(hd)
    shutil.copy(os.path.join(ehv, "EHYPVIEW.PRG"), hd)
    shutil.copy(os.path.join(ROOT, "binary", "EMAIL.HYP"), hd)
    with open(os.path.join(hd, "ST-GUIDE.INF"), "w", newline="") as f:
        f.write("PATHS=C:\\\r\nDEFHYP=C:\\EMAIL.HYP\r\n")
    r = rig.Rig(w, tos, machine=machine, auto="C:\\EHYPVIEW.PRG", extra=extra)
    try:
        time.sleep(25)
        r.shot("%s-1" % name)
        for i in range(2, 5):
            r.key(K["DOWN"], shift=True)     # a page down
            time.sleep(1)
            r.shot("%s-%d" % (name, i))
    finally:
        r.stop()
    log = open(os.path.join(w, "hatari.log"), errors="replace").read()
    check("%s: EHypView %s opens EMAIL.HYP's front page" % (name, tag), "EHV page C:\\EMAIL.HYP Main" in log)
    check("%s: with both its pictures" % name, "EHV pictures 2" in log)


look("falcon", "falcon", ("--memsize", "14"))
look("tt", "tt", ("--monitor", "mono", "--memsize", "4"))
print("screenshots in", work)
ok = checks and all(checks)
print("PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
