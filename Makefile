CFLAGS:=-std=c99 $(shell pkg-config --cflags gtk+-2.0 gthread-2.0) -ggdb -W -Wall -Wextra -DDEBUG_MESSAGES -DCOMMIT="\"$(shell ./build-tools/hash.sh)\""
LDFLAGS:=$(shell pkg-config --libs gtk+-2.0 gthread-2.0 lua libxdg-basedir) -pthread $(LDFLAGS)

SRC=$(wildcard *.c)
HEAD=$(wildcard *.h)
OBJ=$(foreach obj, $(SRC:.c=.o), $(obj))

all: luakit

.c.o:
	@echo -e "${CC} -c ${CFLAGS} $<"
	@${CC} -c ${CFLAGS} $<

${OBJ}: ${HEAD}

luakit: ${OBJ}
	@echo -e "${CC} -o $@ ${OBJ} ${LDFLAGS}"
	@${CC} -o $@ ${OBJ} ${LDFLAGS}

clean:
	rm -f *.o luakit
