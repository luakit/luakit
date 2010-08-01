# Include makefile config
include config.mk

# Token lib generation
GPERF = common/tokenize.gperf
GSRC  = common/tokenize.c
GHEAD = common/tokenize.h

SRCS  = $(filter-out ${GSRC},$(wildcard *.c) $(wildcard common/*.c) $(wildcard widgets/*.c)) ${GSRC}
HEADS = $(filter-out ${GHEAD},$(wildcard *.h) $(wildcard common/*.h) $(wildcard widgets/*.h)) ${GHEAD}
OBJS  = $(foreach obj,$(SRCS:.c=.o),$(obj))

all: options newline luakit

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

${OBJS}: ${HEADS} config.mk

luakit: ${OBJS}
	@echo ${CC} -o $@ ${OBJS}
	@${CC} -o $@ ${OBJS} ${LDFLAGS}

clean:
	rm -rf luakit ${OBJS} ${GSRC} ${GHEAD}

install:
	install -d ${INSTALLDIR}/share/luakit/
	install -d ${DOCDIR}
	install -m644 README.md AUTHORS COPYING* ${DOCDIR}
	cp -r lib ${INSTALLDIR}/share/luakit/
	chmod -R 755 ${INSTALLDIR}/share/luakit/lib/
	install -D luakit ${INSTALLDIR}/bin/luakit
	install -d /etc/xdg/luakit/
	install -D rc.lua /etc/xdg/luakit/rc.lua

uninstall:
	rm -rf ${INSTALLDIR}/bin/luakit ${INSTALLDIR}/share/luakit

newline:;@echo
.PHONY: all clean options install newline
