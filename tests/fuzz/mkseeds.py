#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 AERA | Erez Yaary
"""Writes tests/fuzz/seeds/: the starting inputs for make fuzz, sessions as
mail servers answer them, and messages. For fuzz_imap and fuzz_smtp the
first byte picks what is asked (see the targets); the rest is what the
server says.

tests/fuzz/found/ holds the inputs that once broke a parser: those the
fuzzer found (as it saved them) and those below, made by hand; make test
runs them all again (common/tests/fuzz/replay.c)."""
import base64, os

HERE = os.path.dirname(os.path.abspath(__file__))
MAIL = os.path.join(HERE, "..", "mail")


def put(target, name, data, where="seeds"):
    d = os.path.join(HERE, where, target)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, name), "wb") as f:
        f.write(data if isinstance(data, bytes) else data.encode("latin-1"))


def lit(s):
    return "{%d}\r\n%s" % (len(s.encode("latin-1")), s)


GREET = ("* OK [CAPABILITY IMAP4rev1 SASL-IR AUTH=PLAIN UIDPLUS MOVE SPECIAL-USE NAMESPACE LITERAL+] ready\r\n")
LOGIN = "T0001 OK [CAPABILITY IMAP4rev1 UIDPLUS MOVE SPECIAL-USE] Logged in\r\n"
LOGIN2 = "T0002 OK done\r\n"


def session(sel, *replies):
    return bytes([sel]) + (GREET + LOGIN + "".join(replies)).encode("latin-1")


def main():
    msgs = [open(os.path.join(MAIL, f), "rb").read() for f in sorted(os.listdir(MAIL))]
    hdr = "From: Maya <maya@example.org>\r\nSubject: =?UTF-8?B?16nXnNeV150=?=\r\nDate: Thu, 15 Oct 2026 08:00:00 +0300\r\n\r\n"
    put("imap", "list", session(0,
        '* LIST (\\HasNoChildren) "/" INBOX\r\n* LIST (\\HasNoChildren \\Sent) "/" "Sent Messages"\r\n'
        '* LIST (\\Noselect \\HasChildren) "/" "[Gmail]"\r\n* LIST (\\Trash) "/" {6}\r\nTrash!\r\n', "T0002 OK LIST done\r\n"))
    put("imap", "status", session(1, '* STATUS INBOX (MESSAGES 231 UNSEEN 4)\r\n', LOGIN2))
    put("imap", "status-many", session(2, '* STATUS INBOX (MESSAGES 3 UNSEEN 1)\r\n', LOGIN2,
        '* STATUS Sent (MESSAGES 9 UNSEEN 0)\r\n', "T0003 OK\r\n", "T0004 NO [NONEXISTENT] no Archive\r\n"))
    sel = ('* 3 EXISTS\r\n* 0 RECENT\r\n* OK [UIDVALIDITY 1234] ok\r\n* OK [UIDNEXT 44] ok\r\n'
           '* FLAGS (\\Seen \\Answered \\Flagged \\Deleted \\Draft $Forwarded)\r\nT0002 OK [READ-ONLY] selected\r\n')
    fetch = "".join('* %d FETCH (UID %d FLAGS (\\Seen) RFC822.SIZE 1200 INTERNALDATE "15-Oct-2026 08:00:00 +0300" '
                    'BODY[HEADER.FIELDS (FROM SUBJECT DATE)] %s)\r\n' % (i, 40 + i, lit(hdr)) for i in (1, 2, 3))
    put("imap", "fetch", session(3, sel, fetch, "T0003 OK fetched\r\n"))
    put("imap", "fetch-seq", session(4, sel.replace("[READ-ONLY]", "[READ-WRITE]"),
        "* 98 FETCH (UID 41 FLAGS ())\r\n* 99 FETCH (FLAGS (\\Flagged) UID 42)\r\nT0003 OK\r\n"))
    body = msgs[0].decode("latin-1")
    put("imap", "body", session(5, sel, "* 1 FETCH (UID 42 BODY[] %s)\r\n" % lit(body), "T0003 OK\r\n"))
    put("imap", "append-move", session(6, "+ go ahead\r\n", "T0002 OK [APPENDUID 1234 45] appended\r\n",
        "* OK [COPYUID 1234 1:3 7:9] moved\r\n* 1 EXPUNGE\r\n* 1 EXPUNGE\r\n* 1 EXPUNGE\r\nT0003 OK moved\r\n"))
    put("imap", "store", session(7, "* 1 FETCH (FLAGS (\\Seen \\Flagged))\r\nT0002 OK\r\n", "* 1 EXPUNGE\r\nT0003 OK\r\n",
        "T0004 OK\r\n"))
    put("imap", "login-literal", bytes([0x80]) + (
        "* OK ready\r\nT0001 OK [CAPABILITY IMAP4rev1 AUTH=PLAIN] caps\r\n" + "+ \r\n" +
        "T0002 OK logged in\r\n* LIST () \"/\" INBOX\r\nT0003 OK\r\n").encode())
    put("pop3", "session", "+OK POP3 ready <1.2@pop>\r\n+OK\r\n+OK logged in\r\n+OK 2 3400\r\n"
        "+OK\r\n1 abc-1\r\n2 abc-2\r\n.\r\n+OK\r\n1 1200\r\n2 2200\r\n.\r\n+OK message\r\n" +
        msgs[1].decode("latin-1").replace("\n.", "\n..") + "\r\n.\r\n+OK deleted\r\n+OK bye\r\n")
    put("smtp", "plain-auth", b"\x01" + (
        "220 smtp.example.org ESMTP\r\n250-smtp.example.org\r\n250-PIPELINING\r\n250-SIZE 35882577\r\n"
        "250-AUTH PLAIN LOGIN\r\n250 8BITMIME\r\n235 2.7.0 Accepted\r\n250 OK\r\n250 OK\r\n250 OK\r\n"
        "354 go\r\n250 2.0.0 queued\r\n221 bye\r\n").encode())
    put("smtp", "login-auth", b"\x01" + (
        "220-smtp.example.org\r\n220 ESMTP\r\n250-x\r\n250 AUTH LOGIN\r\n334 VXNlcm5hbWU6\r\n334 UGFzc3dvcmQ6\r\n"
        "235 ok\r\n250 OK\r\n550 5.1.1 no such user\r\n250 OK\r\n354 go\r\n250 queued\r\n221 bye\r\n").encode())
    put("smtp", "no-auth", b"\x00" + (
        "220 gw ESMTP\r\n250 gw\r\n250 OK\r\n250 OK\r\n250 OK\r\n354 go\r\n250 queued\r\n221 bye\r\n").encode())
    for i, m in enumerate(msgs):
        put("mime", "msg%d" % i, m)
    att = base64.b64encode(bytes(range(256)) * 4).decode()
    put("mime", "multipart", (
        "From: \"Carter, Maya\" <maya@example.org>\r\nTo: a@example.org, \"B\" <b@example.org>\r\n"
        "Subject: =?ISO-8859-8?Q?=F9=EC=E5=ED?= and =?utf-8?q?caf=C3=A9?=\r\nMIME-Version: 1.0\r\n"
        "Content-Type: multipart/mixed; boundary=\"XX\"\r\n\r\npreamble\r\n--XX\r\n"
        "Content-Type: multipart/alternative; boundary=YY\r\n\r\n--YY\r\nContent-Type: text/plain; charset=utf-8\r\n"
        "Content-Transfer-Encoding: quoted-printable\r\n\r\nhello =C3=A9 wor=\r\nld\r\n--YY\r\n"
        "Content-Type: text/html; charset=windows-1255\r\n\r\n<html><body><p>hi &amp; <b>bold</b><br>"
        "&#1488;</p><style>x{}</style></body></html>\r\n--YY--\r\n--XX\r\n"
        "Content-Type: application/octet-stream; name*=UTF-8''%D7%A9.bin\r\n"
        "Content-Disposition: attachment; filename=\"a b.bin\"\r\nContent-Transfer-Encoding: base64\r\n\r\n" +
        "\r\n".join(att[i:i + 76] for i in range(0, len(att), 76)) + "\r\n--XX--\r\n"))

    # by hand: a literal of minus five bytes (memmove of -1 bytes), one of
    # four gigabytes, one cut short; STAT counts that size three arrays past
    # 32 bits on the Atari (2^30) and past 64 here (2^62); EHLO extensions
    # longer than the buffer
    put("imap", "literal-negative", session(5, sel, "* 1 FETCH (UID 42 BODY[] {-5}\r\nabc)\r\n", "T0003 OK\r\n"), "found")
    put("imap", "literal-huge", session(5, sel, "* 1 FETCH (UID 42 BODY[] {4294967295}\r\nabc)\r\n", "T0003 OK\r\n"),
        "found")
    put("imap", "literal-cut-short", session(0, '* LIST () "/" {40}\r\nIN'), "found")
    put("imap", "list-unclosed", session(0, '* LIST (\\HasNoChildren "/" {', "\r\n"), "found")
    for name, n in (("stat-huge", 1 << 30), ("stat-huge-64", 1 << 62), ("stat-negative", -3)):
        # (the target's STAT, then pop3_list's)
        put("pop3", name, "+OK ready\r\n+OK\r\n+OK logged in\r\n" + "+OK %d 3400\r\n" % n * 2 +
            "+OK\r\n1 abc-1\r\n.\r\n+OK\r\n1 1200\r\n.\r\n", "found")
    put("smtp", "ehlo-long", b"\x01" + ("220 smtp.example.org ESMTP\r\n" + "".join(
        "250-X%03d %s\r\n" % (i, "A" * 60) for i in range(40)) + "250 AUTH PLAIN\r\n235 ok\r\n221 bye\r\n").encode(), "found")


if __name__ == "__main__":
    main()
