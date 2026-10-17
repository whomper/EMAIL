#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 AERA | Erez Yaary
# builds DSPTEST.PRG (run `make` in the top directory first)
set -e
H=$(cd "$(dirname "$0")" && pwd)
M=$(cd "$H/../.." && pwd)
CC=m68k-linux-gnu-gcc
GCCINC=$($CC -print-file-name=include)
CF="-m68000 -Os -fomit-frame-pointer -ffreestanding -fno-builtin -fno-pic -fno-pie
 -fno-store-merging -fno-expensive-optimizations -fno-asynchronous-unwind-tables -nostdinc -isystem $GCCINC -I$M/atari/include -I$M/common/atari/include -I$M/atari -I$M/common/atari -I$M/src -I$H -DMAIL_TOS -Wall"
mkdir -p "$M/build/dsptest"
$CC $CF -c -o "$M/build/dsptest/dsptest.o" "$H/dsptest.c"
$CC $CF -c -o "$M/build/dsptest/dsprsa.o" "$M/common/atari/dsprsa.c"
$CC -m68000 -nostdlib -static -no-pie -Wl,--emit-relocs -Wl,-T,$M/common/atari/link.ld -Wl,--build-id=none \
  -Wl,-z,noexecstack -Wl,--no-warn-rwx-segments -o "$M/build/dsptest/dsptest.elf" \
  $M/build/crt0.o "$M/build/dsptest/dsptest.o" "$M/build/dsptest/dsprsa.o" $M/build/tos.o $M/build/libc.o $M/build/nf.o
PRGFLAGS=7 python3 "$M/common/tools/elf2tos.py" "$M/build/dsptest/dsptest.elf" "$H/DSPTEST.PRG"
