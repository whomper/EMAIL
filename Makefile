# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Erez Yaary
# EMail - an email client for the Atari ST/STE/TT/Falcon, in C.
#
#   make            builds EMAIL.PRG with a stock m68k ELF cross compiler
#                   (Debian/Ubuntu: apt install gcc-m68k-linux-gnu).
#                   No MiNTLib needed: the program is freestanding and
#                   common/tools/elf2tos.py writes the TOS header.
#   make test       builds the mail core for this computer and runs the
#                   unit tests (tests/); `make itest` also runs the
#                   protocol tests against a local Dovecot.
#
# The Atari build follows Claude ST (github.com/whomper/ClaudeST). The code
# EMail shares with the other AERA programs (BearSSL, the DSP RSA, bidi,
# dates, passwords, the libc headers, the build tools) is in common/, a git
# subtree of github.com/whomper/AERA-Atari: change it there, then
# tools/sync-common.sh.

CROSS   ?= m68k-linux-gnu-
CC      := $(CROSS)gcc
GCCINC  := $(shell $(CC) -print-file-name=include)
CFLAGS  := -m68000 -Os -fomit-frame-pointer -ffreestanding -fno-builtin \
           -fno-pic -fno-pie -fno-tree-loop-distribute-patterns -fno-store-merging \
           -fno-asynchronous-unwind-tables -Wall -Wno-pointer-sign \
           -DMAIL_TOS -nostdinc -isystem $(GCCINC) -Iatari/include -Icommon/atari/include \
           -Isrc -Icommon/src -Iatari -Icommon/atari -Iui -Icommon/ui -Icommon/third_party/bearssl/inc
LDFLAGS := -m68000 -nostdlib -static -no-pie -Wl,--emit-relocs -Wl,-T,common/atari/link.ld \
           -Wl,--build-id=none -Wl,-z,noexecstack -Wl,--no-warn-rwx-segments

# BearSSL 0.6 (common/third_party/bearssl) for Falcon mode. On the Atari it is
# built for the 68030: Falcon mode needs one, the rest of EMail stays
# 68000 code and runs on any ST.
BSSL    := common/third_party/bearssl
BSSLSRC := $(wildcard $(BSSL)/src/*/*.c)
BSSLDEF := -DBR_USE_URANDOM=0 -DBR_USE_GETENTROPY=0 -DBR_USE_UNIX_TIME=0 \
           -DBR_USE_WIN32_TIME=0 -DBR_USE_WIN32_RAND=0 -DBR_RDRAND=0
BSSLCF  := -m68030 -O2 -fomit-frame-pointer -ffreestanding -fno-builtin -fno-pic -fno-pie \
           -fno-tree-loop-distribute-patterns -fno-asynchronous-unwind-tables -w \
           -nostdinc -isystem $(GCCINC) -Iatari/include -Icommon/atari/include -I$(BSSL)/inc -I$(BSSL)/src $(BSSLDEF)
BSSLOBJ  = $(patsubst $(BSSL)/src/%.c,$(OBJDIR)/bssl/%.o,$(BSSLSRC))
HBSSLOBJ = $(patsubst $(BSSL)/src/%.c,$(OBJDIR)/hbssl/%.o,$(BSSLSRC))

CORE    := util charset mime conn tls imap pop3 smtp store compose mail futil bidi secret ctime tz
ATARI   := libc tos plat_tos net_tos sting gem dsprsa crash
UI      := main draw win folders list reader editor dialogs popup font about dsp theme help av alert mbar aboutbox iconify clip clipedit dd busy

OBJDIR  := build
OBJS    := $(OBJDIR)/crt0.o $(OBJDIR)/sting_s.o $(OBJDIR)/nf.o $(OBJDIR)/crash_s.o \
           $(addprefix $(OBJDIR)/,$(addsuffix .o,$(CORE) $(ATARI) $(UI)))
HDRS    := $(wildcard src/*.h atari/*.h atari/include/*.h ui/*.h \
           common/src/*.h common/atari/*.h common/atari/include/*.h common/dsp/*.h)

all: binary/EMAIL.PRG binary/ROOTS.DAT

binary/EMAIL.PRG: $(OBJDIR)/mail.elf common/tools/elf2tos.py
	PRGFLAGS=7 python3 common/tools/elf2tos.py $< $@

# Every build of EMAIL.PRG gets the next version: the minor number in
# VERSION (major.minor, e.g. 1.6) goes up by one each time the program is
# linked, for the About box and the User-Agent header. Commit VERSION
# with the program.
$(OBJDIR)/mail.elf: $(OBJS) $(OBJDIR)/libbearssl.a common/atari/link.ld
	v=$$(cat VERSION); v=$${v%%.*}.$$(( $${v#*.} + 1 )); echo $$v > VERSION; \
	printf 'const char mail_version[] = "%s";\n' $$v > $(OBJDIR)/build.c
	$(CC) $(CFLAGS) -c -o $(OBJDIR)/build.o $(OBJDIR)/build.c
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(OBJDIR)/build.o $(OBJDIR)/libbearssl.a -lgcc
	@echo "EMail $$(cat VERSION)"

$(OBJDIR)/bssl/%.o: $(BSSL)/src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(BSSLCF) -c -o $@ $<

$(OBJDIR)/libbearssl.a: $(BSSLOBJ)
	rm -f $@
	$(CROSS)ar rcs $@ $^

$(OBJDIR)/%.o: src/%.c $(HDRS) | $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ $<
$(OBJDIR)/%.o: atari/%.c $(HDRS) | $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ $<
$(OBJDIR)/%.o: ui/%.c $(HDRS) | $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ $<
$(OBJDIR)/%.o: common/src/%.c $(HDRS) | $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ $<
$(OBJDIR)/%.o: common/atari/%.c $(HDRS) | $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ $<
$(OBJDIR)/%.o: common/ui/%.c $(HDRS) | $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ $<
$(OBJDIR)/crt0.o: common/atari/crt0.S | $(OBJDIR)
	$(CC) -m68000 -c -o $@ $<
$(OBJDIR)/sting_s.o: common/atari/sting.S | $(OBJDIR)
	$(CC) -m68000 -c -o $@ $<
$(OBJDIR)/crash_s.o: common/atari/crash.S | $(OBJDIR)
	$(CC) -m68000 -c -o $@ $<
$(OBJDIR)/nf.o: common/atari/nf.S | $(OBJDIR)
	$(CC) -m68000 -c -o $@ $<

$(OBJDIR):
	mkdir -p $@

# ---- host build: the same mail core, for tests and mail-cli ----
HOSTCC     ?= cc
HOSTCFLAGS := -O1 -g -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare \
              -Wno-format-truncation -Isrc -Icommon/src -fsanitize=address,undefined
# each core file is the app's own (src/) or shared (common/src/)
HOSTSRC    := $(foreach m,$(CORE),$(firstword $(wildcard src/$(m).c common/src/$(m).c))) \
              tests/host/plat_posix.c tests/host/version.c
HOSTLIB    := $(OBJDIR)/libbearssl-host.a

$(OBJDIR)/hbssl/%.o: $(BSSL)/src/%.c
	@mkdir -p $(dir $@)
	$(HOSTCC) -O2 -w -I$(BSSL)/inc -I$(BSSL)/src -c -o $@ $<

$(HOSTLIB): $(HBSSLOBJ)
	rm -f $@
	ar rcs $@ $^

$(OBJDIR)/mail-cli: tests/host/mail_cli.c $(HOSTSRC) $(HDRS) $(HOSTLIB) | $(OBJDIR)
	$(HOSTCC) $(HOSTCFLAGS) -I$(BSSL)/inc -o $@ tests/host/mail_cli.c $(HOSTSRC) $(HOSTLIB)

$(OBJDIR)/unit: tests/unit.c $(HOSTSRC) $(HDRS) $(HOSTLIB) | $(OBJDIR)
	$(HOSTCC) $(HOSTCFLAGS) -I$(BSSL)/inc -o $@ tests/unit.c $(HOSTSRC) $(HOSTLIB)

# the root certificates, decoded ahead of time for Falcon mode
$(OBJDIR)/mkroots: common/tools/mkroots.c $(HOSTSRC) $(HDRS) $(HOSTLIB) | $(OBJDIR)
	$(HOSTCC) $(HOSTCFLAGS) -I$(BSSL)/inc -o $@ common/tools/mkroots.c $(HOSTSRC) $(HOSTLIB)

# (Mozilla's list, kept in common/, next to the program)
binary/CACERT.PEM: common/certs/CACERT.PEM
	cp $< $@
binary/ROOTS.DAT: binary/CACERT.PEM $(OBJDIR)/mkroots
	$(OBJDIR)/mkroots binary/CACERT.PEM $@

# ---- fuzzing (the AERA guidelines, 7.1): what servers send, from
# libFuzzer, with AddressSanitizer and UBSan. The network is
# common/tests/fuzz/fuzz_net.c: the server says the fuzz input. Needs
# clang with libFuzzer (Debian/Ubuntu: clang, libclang-rt-dev); make fuzz
# runs each target FUZZTIME seconds from tests/fuzz/seeds (mkseeds.py)
FUZZCC    ?= clang
FUZZTIME  ?= 60
FUZZERS   := imap pop3 smtp mime
FUZZFLAGS := -g -O1 -fsanitize=fuzzer,address,undefined -fno-sanitize-recover=undefined -DFUZZ_NET \
             -Isrc -Icommon/src -Icommon/tests/fuzz -I$(BSSL)/inc

$(OBJDIR)/fuzz_%: tests/fuzz/fuzz_%.c $(HOSTSRC) $(HDRS) $(HOSTLIB) common/tests/fuzz/fuzz_net.c | $(OBJDIR)
	$(FUZZCC) $(FUZZFLAGS) -o $@ $< $(HOSTSRC) common/tests/fuzz/fuzz_net.c $(HOSTLIB)

fuzz: $(addprefix $(OBJDIR)/fuzz_,$(FUZZERS))
	@for f in $(FUZZERS); do \
	  mkdir -p $(OBJDIR)/corpus/$$f; \
	  echo "fuzz_$$f: $(FUZZTIME) s"; \
	  $(OBJDIR)/fuzz_$$f -max_total_time=$(FUZZTIME) -timeout=10 -rss_limit_mb=1024 \
	    -artifact_prefix=$(OBJDIR)/crash-$$f- $(OBJDIR)/corpus/$$f tests/fuzz/seeds/$$f \
	    $$(ls -d tests/fuzz/found/$$f 2>/dev/null) \
	    > $(OBJDIR)/fuzz_$$f.log 2>&1 || { tail -40 $(OBJDIR)/fuzz_$$f.log; exit 1; }; \
	  grep -E "^#[0-9]+.*DONE" $(OBJDIR)/fuzz_$$f.log | tail -1; \
	done

# the same targets without libFuzzer (common/tests/fuzz/replay.c), with
# this computer's compiler: make test runs the seeds again, and the inputs
# that once broke a parser (tests/fuzz/found)
REPLAYFLAGS := $(HOSTCFLAGS) -fno-sanitize-recover=undefined -DFUZZ_NET -Icommon/tests/fuzz -I$(BSSL)/inc
REPLAYSRC   := common/tests/fuzz/fuzz_net.c common/tests/fuzz/replay.c

$(OBJDIR)/replay_%: tests/fuzz/fuzz_%.c $(HOSTSRC) $(HDRS) $(HOSTLIB) $(REPLAYSRC) | $(OBJDIR)
	$(HOSTCC) $(REPLAYFLAGS) -o $@ $< $(HOSTSRC) $(REPLAYSRC) $(HOSTLIB)

test: $(OBJDIR)/unit $(addprefix $(OBJDIR)/replay_,$(FUZZERS))
	$(OBJDIR)/unit
	@for f in $(FUZZERS); do \
	  $(OBJDIR)/replay_$$f tests/fuzz/seeds/$$f $$(ls -d tests/fuzz/found/$$f 2>/dev/null) || exit 1; \
	done
	python3 -m unittest discover -s gateway -p 'test_*.py'

itest: $(OBJDIR)/mail-cli
	tests/integration.sh

# the ST-Guide help file from the user guide (HCP from github.com/th-otto/hypview)
HCP ?= hcp
# (and EMAIL.REF, its page names for ST-Guide's reference list)
help: binary/EMAIL.HYP
binary/EMAIL.HYP: docs/GUIDE.md tools/mkhelp.py VERSION
	@mkdir -p $(OBJDIR)
	python3 tools/mkhelp.py docs/GUIDE.md VERSION $(OBJDIR)/EMAIL.STG
	$(HCP) --references -o $@ $(OBJDIR)/EMAIL.STG >/dev/null

clean:
	rm -rf $(OBJDIR) binary/EMAIL.PRG binary/ROOTS.DAT

.PHONY: help all test itest clean fuzz
