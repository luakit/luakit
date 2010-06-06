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
	@echo "PREFIX     = ${PREFIX}"
	@echo "MANPREFIX  = ${MANPREFIX}"
	@echo "DESTDIR    = ${DESTDIR}"
	@echo
	@echo build targets:
	@echo "SRCS       = ${SRCS}"
	@echo "HEADS      = ${HEADS}"
	@echo "OBJS       = ${OBJS}"
	@echo "TARGETS    = ${TARGETS}"

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
	@echo Are you insane?

newline:;@echo
.PHONY: all clean options install newline
