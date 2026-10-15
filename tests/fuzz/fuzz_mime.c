/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (C) 2026 Erez Yaary */
/*
 * A message as it arrives (the AERA guidelines, 7.1): the headers and
 * their encodings, the MIME structure, the text to show (HTML made text,
 * charsets made Atari text), every attachment decoded, the addresses
 * split.
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "mime.h"

int LLVMFuzzerTestOneInput(const uint8_t *d, size_t n)
{
	char *raw = malloc(n + 1), name[100], email[100];
	MSG *m;
	long hl, len;
	int i;
	if (!raw)
		return 0;
	memcpy(raw, d, n);
	raw[n] = 0;
	m = mime_parse(raw, (long)n);
	if (m) {
		for (i = 0; i < m->nparts; i++)
			free(mime_part_data(raw, &m->parts[i], &len));
		if (m->from)
			addr_split(m->from, name, sizeof(name), email, sizeof(email));
		mime_free(m);
	}
	hl = mime_header_len(raw, (long)n);
	if (hl > 0) {
		char *ct = mime_header(raw, hl, "Content-Type");
		if (ct) {
			free(mime_param(ct, "boundary"));
			free(mime_param(ct, "charset"));
			free(ct);
		}
	}
	free(html_to_text(raw, (long)n, &len));
	free(raw);
	return 0;
}
