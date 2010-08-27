# Include makefile config
include config.mk

# Token lib generation
GPERF = common/tokenize.gperf
GSRC  = common/tokenize.c
GHEAD = common/tokenize.h

SRCS  = $(filter-out ${GSRC},$(wildcard *.c) $(wildcard common/*.c) $(wildcard widgets/*.c)) ${GSRC}
HEADS = $(filter-out ${GHEAD},$(wildcard *.h) $(wildcard common/*.h) $(wildcard widgets/*.h)) ${GHEAD}
OBJS  = $(foreach obj,$(SRCS:.c=.o),$(obj))

all: options newline luakit luakit.1

options:
	@echo luakit build options:
	@echo "CC         = ${CC}"
	@echo "CFLAGS     = ${CFLAGS}"
	@echo "CPPFLAGS   = ${CPPFLAGS}"
	@echo "LDFLAGS    = ${LDFLAGS}"
	@echo "INSTALLDIR = ${INSTALLDIR}"
	@echo "MANPREFIX  = ${MANPREFIX}"
	@echo "DOCDIR     = ${DOCDIR}"
	@echo
	@echo build targets:
	@echo "SRCS       = ${SRCS}"
	@echo "HEADS      = ${HEADS}"
	@echo "OBJS       = ${OBJS}"

${GSRC} ${GHEAD}: ${GPERF}
	./build-utils/gperf.sh $< $@

.c.o:
	@echo ${CC} -c $< -o $@
	@${CC} -c ${CFLAGS} ${CPPFLAGS} $< -o $@

globalconf.h: globalconf.h.in
	sed 's#LUAKIT_INSTALL_PATH .*#LUAKIT_INSTALL_PATH "$(PREFIX)/share/luakit"#' globalconf.h.in > globalconf.h

${OBJS}: ${HEADS} config.mk globalconf.h

luakit: ${OBJS}
	@echo ${CC} -o $@ ${OBJS}
	@${CC} -o $@ ${OBJS} ${LDFLAGS}

luakit.1: luakit
	help2man -N -o $@ ./$<

apidoc: luadoc/luakit.lua
	mkdir -p apidocs
	luadoc --nofiles -d apidocs luadoc/* lib/*

clean:
	rm -rf apidocs luakit ${OBJS} ${GSRC} ${GHEAD} globalconf.h luakit.1

install:
	install -d $(INSTALLDIR)/share/luakit/
	install -d $(DOCDIR)
	install -m644 README.md AUTHORS COPYING* $(DOCDIR)
	cp -r lib/ $(INSTALLDIR)/share/luakit/
	chmod -R 755 $(INSTALLDIR)/share/luakit/lib/
	cp -r scripts/ $(INSTALLDIR)/share/luakit/
	chmod -R 755 $(INSTALLDIR)/share/luakit/scripts/
	install -D luakit $(INSTALLDIR)/bin/luakit
	install -d $(DESTDIR)/etc/xdg/luakit/
	install -D config/*.lua $(DESTDIR)/etc/xdg/luakit/
	install -d $(INSTALLDIR)/share/man/man1/
	install -m644 luakit.1 $(INSTALLDIR)/share/man/man1/

uninstall:
	rm -rf $(INSTALLDIR)/bin/luakit $(INSTALLDIR)/share/luakit $(INSTALLDIR)/share/man/man1/luakit.1

newline:;@echo
.PHONY: all clean options install newline apidoc
