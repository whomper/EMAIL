/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (C) 2026 Erez Yaary */
/*
 * crash.h - the crash catcher. A bus error, address error, illegal
 * instruction and the like in EMail (the 2 to 8 bombs) no longer leave
 * the bombs and a shaky machine: EMail writes what happened to CRASH.LOG,
 * says so and quits. A crash in the system or a driver still gives the
 * bombs; TOS keeps a record of them, which EMail adds to CRASH.LOG the
 * next time it starts. Plain TOS only: MiNT and MagiC catch crashes
 * themselves.
 */
#ifndef CRASH_H
#define CRASH_H

/* install the handlers; workdir is where CRASH.LOG goes */
void crash_install(const char *workdir);
/* put the vectors back (also done by itself however EMail ends) */
void crash_remove(void);
/* what EMail was doing, for the report (the status line's text) */
void crash_note(const char *what);
/* after a crash, with the report written: tell the user and close GEM
   down (set by the UI) */
extern void (*crash_cleanup)(const char *what);
/* a crash TOS recorded before this run: its report is in CRASH.LOG; the
   bombs' name when the crash was in EMail's code, else 0 */
const char *crash_previous(void);

#endif
