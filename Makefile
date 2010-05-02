# Include makefile config
include config.mk

SRC=$(wildcard *.c)
HEAD=$(wildcard *.h)
OBJS=$(foreach obj, $(SRC:.c=.o), $(obj))

all: options newline luakit

options:
	@echo luakit build options:
	@echo "CC         = ${CC}"
	@echo "CFLAGS     = ${CFLAGS}"
	@echo "LDFLAGS    = ${LDFLAGS}"
	@echo "CPPFLAGS   = ${CPPFLAGS}"
	@echo "PREFIX     = ${PREFIX}"
	@echo "MANPREFIX  = ${MANPREFIX}"
	@echo "DESTDIR    = ${DESTDIR}"

.c.o:
	@echo ${CC} -c $<
	@${CC} -c ${CFLAGS} $<

${OBJS}: ${HEAD} config.mk

luakit: ${OBJS}
	@echo ${CC} -o $@ ${OBJS}
	@${CC} -o $@ ${OBJS} ${LDFLAGS}

clean:
	rm -f luakit ${OBJS}

install:
	@echo Are you insane?

newline:;@echo
.PHONY: all clean options install newline
