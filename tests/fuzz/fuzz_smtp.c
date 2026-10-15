/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (C) 2026 Erez Yaary */
/*
 * An SMTP server's answers, from the fuzz input (the AERA guidelines,
 * 7.1): the greeting, EHLO and its keywords, the login, a message sent.
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "smtp.h"
#include "fuzz_net.h"

int LLVMFuzzerTestOneInput(const uint8_t *d, size_t n)
{
	static const char data[] = "From: a@example.org\r\nTo: b@example.org\r\nSubject: hi\r\n\r\n.dot\r\nbody\r\n";
	const char *rcpts[] = { "b@example.org", "c@example.org" };
	char err[200];
	SMTP *s;
	int sel;
	if (n < 1)
		return 0;
	sel = d[0];
	fuzz_net_set(d + 1, (long)n - 1);
	s = smtp_open("smtp.example.org", 587, 0, "atari.example", (sel & 1) ? "user" : "", "secret",
		      err, sizeof(err));
	if (!s)
		return 0;
	smtp_send(s, "a@example.org", rcpts, 2, data, (long)sizeof(data) - 1);
	smtp_quit(s);
	return 0;
}
