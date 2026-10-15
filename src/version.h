/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (C) 2026 AERA | Erez Yaary */
/* EMail's version, shown in the About box and the User-Agent header:
   VERSION holds the last release (major.minor, "1.30"), which a release
   build shows; other builds show "1.30-dev". The Makefile writes build.c;
   tools/bump.py starts a release. */
#ifndef VERSION_H
#define VERSION_H
extern const char mail_version[];
#endif
