/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (C) 2026 Erez Yaary */
/*
 * An IMAP server's answers, from the fuzz input (the AERA guidelines,
 * 7.1): the greeting and capabilities, the login, then what the first
 * byte picks: folders (LIST, STATUS), a folder's messages (SELECT, FETCH
 * of flags, sizes, headers, literals of any length), a whole message.
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "imap.h"
#include "fuzz_net.h"

static void folder(void *ud, const char *name, char delim, int role, int noselect)
{
	(void)ud;
	(void)delim;
	(void)role;
	(void)noselect;
	(void)strlen(name);
}

static void fetched(void *ud, IMAPFETCH *f)
{
	volatile long sum = 0;
	long i;
	(void)ud;
	for (i = 0; f->hdr && i < f->hdrlen; i++)
		sum += f->hdr[i];
	for (i = 0; f->body && i < f->bodylen; i++)
		sum += f->body[i];
	sum += (long)strlen(f->internaldate);
}

int LLVMFuzzerTestOneInput(const uint8_t *d, size_t n)
{
	char err[200];
	IMAP *im;
	int sel;
	if (n < 1)
		return 0;
	sel = d[0];
	fuzz_net_set(d + 1, (long)n - 1);
	im = imap_login("imap.example.org", 143, 0, "user@example.org", (sel & 0x80) ? "p\xe4ss" : "secret",
			err, sizeof(err));
	if (!im)
		return 0;
	switch (sel & 7) {
	case 0:
		imap_list(im, folder, 0);
		break;
	case 1: {
		long m, u;
		imap_status(im, "INBOX", &m, &u);
		break;
	}
	case 2: {
		const char *const boxes[] = { "INBOX", "Sent", "Archive" };
		long m[3], u[3];
		imap_status_many(im, boxes, 3, m, u);
		break;
	}
	case 3:
		if (imap_select(im, "INBOX", 1) > 0)
			imap_fetch(im, "1:*", "(UID FLAGS RFC822.SIZE INTERNALDATE BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])",
				   fetched, 0);
		break;
	case 4:
		if (imap_select(im, "INBOX", 0) > 0)
			imap_fetch_seq(im, "98:100", "(UID FLAGS)", fetched, 0);
		break;
	case 5: {
		char *body = 0;
		long len = 0;
		if (imap_select(im, "INBOX", 1) > 0 && imap_fetch_body(im, 42, &body, &len) > 0)
			free(body);
		break;
	}
	case 6:
		imap_append(im, "Sent", MF_SEEN, "Subject: hi\r\n\r\nbody\r\n", 22);
		imap_move(im, "1:3", "Archive");
		break;
	default:
		imap_store(im, "1", 1, MF_SEEN | MF_FLAGGED);
		imap_expunge(im, "1");
		imap_noop(im);
	}
	imap_logout_nowait = 1;
	imap_logout(im);
	return 0;
}
