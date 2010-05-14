# Include makefile config
include config.mk

# Token lib generation
TGPERF = common/tokenize.gperf
TSRC   = common/tokenize.c
THEAD  = common/tokenize.h
TOBJ   = common/tokenize.o

SRCS  = $(filter-out ${TSRC},$(wildcard *.c) $(wildcard common/*.c)) ${TSRC}
HEADS = $(filter-out ${THEAD},$(wildcard *.h) $(wildcard common/*.h)) ${THEAD}
OBJS  = $(foreach obj,$(SRCS:.c=.o),$(obj))

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
	@echo
	@echo build targets:
	@echo "SRCS       = ${SRCS}"
	@echo "HEADS      = ${HEADS}"
	@echo "OBJS       = ${OBJS}"


${TSRC} ${THEAD}: ${TGPERF}
	./build-utils/gperf.sh $< $@

.c.o:
	@echo ${CC} -c $< -o $@
	@${CC} -c ${CFLAGS} $< -o $@


${OBJS}: ${HEADS} config.mk

luakit: ${OBJS}
	@echo ${CC} -o $@ ${OBJS}
	@${CC} -o $@ ${OBJS} ${LDFLAGS}

clean:
	rm -rf luakit ${OBJS} ${TSRC} ${THEAD}

install:
	@echo Are you insane?

newline:;@echo
.PHONY: all clean options install newline
