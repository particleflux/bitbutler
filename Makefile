PREFIX ?= /usr/local
BINDIR ?= ${PREFIX}/bin
DATADIR ?= ${PREFIX}/share
MANDIR ?= ${DATADIR}/man

SHELL = /bin/sh
INSTALL ?= install

PROGRAM_NAME = bitbutler

install: doc
	$(INSTALL) -D -t "${DESTDIR}${DATADIR}/${PROGRAM_NAME}" src/*.sh
	$(INSTALL) -D man/bitbutler.1 $(DESTDIR)$(MANDIR)/man1/${PROGRAM_NAME}.1
	mkdir -p "${DESTDIR}${BINDIR}"
	echo -e '#!/usr/bin/env bash\nBB_VENDOR_PATH="${DESTDIR}${DATADIR}/${PROGRAM_NAME}" exec ${DESTDIR}${DATADIR}/${PROGRAM_NAME}/bitbutler.sh "$$@"' > "${DESTDIR}${BINDIR}/${PROGRAM_NAME}"
	chmod u+rwx,g+x,o+x "${DESTDIR}${BINDIR}/${PROGRAM_NAME}"

doc:
	$(MAKE) -C man

test:
	bats tests

coverage:
	kcov --include-path=. coverage bats tests/

shellcheck:
	find 'src/' -type f -name '*.sh' | xargs shellcheck --external-sources

stylecheck:
	shfmt -i 2 -ci -d src

stylefix:
	shfmt -i 2 -ci -w src

clean:
	$(RM) -r ./coverage
	$(MAKE) -C man clean


.PHONY: install test coverage clean doc shellcheck stylecheck
