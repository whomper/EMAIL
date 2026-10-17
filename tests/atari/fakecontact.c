/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (C) 2026 AERA | Erez Yaary */
/*
 * fakecontact.c - a stand-in for EContact's answering side (the AERA
 * guidelines, 4.1), for tests/hatari/people_test.py: an accessory that
 * answers to the name ECONTACT (as ECONTACT.ACC) and knows four people.
 * names: is answered from them; pick: at once with two of them (a bare
 * pick:, cancelled, when the search text is "none"). Each question goes
 * into C:\PEOPLE.LOG, for the test to read.
 */
#include <string.h>
#include "gem.h"
#include "tos.h"
#include "av.h"
#include "people_ask.h"

static const char *const book[][2] = {
	{ "dana@example.com", "Dana Cohen" },
	{ "avi@example.org", "Avi Levi" },
	{ "maya@pixelpress.example", "Maya Carter" },
	{ "grace@example.net", "Baker, Grace" },
};
#define NBOOK (int)(sizeof(book) / sizeof(book[0]))

static void note(const char *s)
{
	long h = Fopen("C:\\PEOPLE.LOG", 1);
	if (h < 0)
		h = Fcreate("C:\\PEOPLE.LOG", 0);
	if (h < 0)
		return;
	Fseek(0, (short)h, 2);
	Fwrite((short)h, strlen(s), s);
	Fwrite((short)h, 2, "\r\n");
	Fclose((short)h);
}

static const char *known(const char *addr)
{
	int i;
	for (i = 0; i < NBOOK; i++)
		if (!strcmp(book[i][0], addr))
			return book[i][1];
	return "";
}

static void question(const char *s, short from)
{
	char asker[16], addr[PEOPLE_ADDR];
	const char *rest;
	int kind = people_question(s, asker, sizeof(asker), &rest);
	note(s);
	if (kind == PQ_NAMES) {
		int ok;
		people_answer(from, "names:", 0, 0);
		while ((rest = people_next(rest, addr, sizeof(addr))) != 0)
			people_answer(from, 0, addr, known(addr));
		ok = people_answer(from, 0, 0, 0);
		note(ok ? "answered" : "answer not queued");
	} else if (kind == PQ_PICK) {
		people_answer(from, "pick:", 0, 0);
		if (strcmp(rest, "none")) {
			people_answer(from, 0, book[2][0], book[2][1]);
			people_answer(from, 0, book[3][0], book[3][1]);
		}
		people_answer(from, 0, 0, 0);
	}
}

int main(void)
{
	short msg[8];
	AEVENT ev;
	const char *s;
	appl_init();
	av_init("ECONTACT");
	people_init(0, 4096, 0, 0);
	note(av_name());
	for (;;) {
		evnt_multi_(MU_MESAG | MU_TIMER, 0, 0, 0, 100, msg, &ev);
		if ((ev.which & MU_MESAG) && av_message(msg, &s) == AV_PEOPLE)
			question(s, msg[1]);
		people_poll();
	}
}
