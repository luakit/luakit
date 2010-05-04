# Include makefile config
include config.mk

SRCS  = $(wildcard *.c)
HEADS = $(wildcard *.h)
OBJS  = $(foreach obj, $(SRCS:.c=.o), $(obj))

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
	@echo "SRCS       = ${SRCS}"
	@echo "HEADS      = ${HEADS}"
	@echo "OBJS       = ${OBJS}"

.c.o:
	@echo ${CC} -c $<
	@${CC} -c ${CFLAGS} $<

${OBJS}: ${HEADS} config.mk

luakit: ${OBJS}
	@echo ${CC} -o $@ ${OBJS}
	@${CC} -o $@ ${OBJS} ${LDFLAGS}

clean:
	rm -rf luakit ${OBJS}

install:
	@echo Are you insane?

newline:;@echo
.PHONY: all clean options install newline
