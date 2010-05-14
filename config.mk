# Get the current version which is either a nearby git tag or a short-hash
# of the current commit.
VERSION   ?= $(shell ./build-utils/getversion.sh)

# Paths
PREFIX    ?= /usr/local
MANPREFIX ?= ${PREFIX}/share/man

# Generate includes and libs
PKGS := gtk+-2.0 gthread-2.0 webkit-1.0 lua libxdg-basedir
INCS := $(shell pkg-config --cflags ${PKGS}) -I./
LIBS := $(shell pkg-config --libs ${PKGS})

# Add flags
CPPFLAGS := -DVERSION=\"${VERSION}\" -DDEBUG_MESSAGES ${CPPFLAGS}
CFLAGS   := -std=c99 -ggdb -W -Wall -Wextra ${INCS} ${CPPFLAGS} ${CFLAGS}
LDFLAGS  := ${LIBS} ${LDFLAGS}

# Building on OSX
#CFLAGS  += -lgthread-2.0
#LDFLAGS += -pthread

# Building on FreeBSD (or just use gmake)
#VERSION != echo `./build-utils/getversion.sh`
#INCS    != echo -I. -I/usr/include `pkg-config --cflags ${PKGS}`
#LIBS    != echo -L/usr/lib `pkg-config --libs ${PKGS}`

# Custom compiler / linker
#CC = clang
