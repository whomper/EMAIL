/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (C) 2026 AERA | Erez Yaary */
/*
 * A POP3 server's answers, from the fuzz input (the AERA guidelines,
 * 7.1): the login, STAT, UIDL and LIST, a message, DELE.
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "pop3.h"
#include "fuzz_net.h"

static void listed(void *ud, long num, const char *uid, long size)
{
	(void)ud;
	(void)num;
	(void)size;
	(void)strlen(uid);
}

int LLVMFuzzerTestOneInput(const uint8_t *d, size_t n)
{
	char err[200];
	POP3 *p;
	long count, size;
	SBUF msg;
	fuzz_net_set(d, (long)n);
	p = pop3_login("pop.example.org", 110, 0, "user", "secret", err, sizeof(err));
	if (!p)
		return 0;
	pop3_stat(p, &count, &size);
	pop3_list(p, listed, 0);
	sb_init(&msg);
	pop3_retr(p, 1, &msg);
	sb_free(&msg);
	pop3_dele(p, 1);
	pop3_quit(p);
	return 0;
}
