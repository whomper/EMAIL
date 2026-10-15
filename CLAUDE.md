# Notes for working on EMail

- **Every new build gets a new version.** `make` counts the minor number
  in `VERSION` up each time it links `binary/EMAIL.PRG`: commit `VERSION`
  with `binary/`, and never reuse a number. `make help HCP=...` makes
  `binary/EMAIL.HYP` from `docs/GUIDE.md` with that version.
- Before pushing: `make test` (the core, the fuzz inputs again, the
  gateway), `make itest` (against Dovecot: dovecot-imapd, dovecot-pop3d;
  also `TLS=1` and `FALCON=1` when the connection code changes), and
  `make` with no warnings. When the GEM side changes,
  `tests/hatari/net_test.py` and `tests/hatari/stop_test.py` in Hatari
  with EmuTOS.
- `gateway/emailgate.py` is standard Python, installed by
  `gateway/install.sh`; keep it that way. Its log names who connected
  where, never what went through.
- EContact's `integration/EMAIL.patch` makes EContact EMail's address
  book: when EMail changes, make that patch again in EContact (see its
  CLAUDE.md) and check it still applies and builds.
- `common/` is shared AERA code (BearSSL, the DSP RSA, bidi, dates,
  passwords, the GEM building blocks, libc headers, build tools), a git
  subtree of github.com/whomper/AERA-Atari. Don't edit it here: change it
  in AERA-Atari, then run `tools/sync-common.sh`. Follow the AERA Atari
  app guidelines (AERA-Atari, `standards/ATARI-APP-GUIDELINES.md`).
- **The name** reads "AERA | Erez Yaary" wherever it is given: copyright
  lines (`Copyright (C) 2026 AERA | Erez Yaary`), the About box, the help
  file's `@author`, the docs, and as the author of every commit:
  `git commit --author="AERA | Erez Yaary <yaary@me.com>"`, with Claude as
  the signing committer (AERA-Atari, `standards/GITHUB-IDENTITY.md`).
