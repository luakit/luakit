# Get the current version which is either a nearby git tag or a short-hash
# of the current commit.
VERSION   ?= $(shell ./build-utils/getversion.sh)

PREFIX     ?= /usr/local
INSTALLDIR := $(DESTDIR)$(PREFIX)

MANPREFIX  ?= $(PREFIX)/share/man
MANPREFIX  := $(DESTDIR)$(MANPREFIX)

DOCDIR     ?= $(PREFIX)/share/luakit/docs
DOCDIR     := $(DESTDIR)$(DOCDIR)

# Use the Just-In-Time compiler for lua (for faster lua code execution)
# See http://luajit.org/ & http://luajit.org/performance.html for more
# information.
ifeq ($(USE_LUAJIT),1)
LUA_PKG_NAME = $(shell pkg-config --exists luajit && echo luajit)
ifeq ($(LUA_PKG_NAME),)
$(error Unable to determine luajit pkg-config name, specify manually with \
`LUA_PKG_NAME=<name> make`, use `pkg-config --list-all | grep luajit` to \
find the correct package name for your system. Please also check that you \
have luajit installed)
endif
endif

# The lua pkg-config name changes from system to system, try autodetect it.
ifeq ($(LUA_PKG_NAME),)
LUA_PKG_NAME = $(shell pkg-config --exists lua && echo lua)
endif
ifeq ($(LUA_PKG_NAME),)
LUA_PKG_NAME = $(shell pkg-config --exists lua-5.1 && echo lua-5.1)
endif
ifeq ($(LUA_PKG_NAME),)
LUA_PKG_NAME = $(shell pkg-config --exists lua5.1 && echo lua5.1)
endif
ifeq ($(LUA_PKG_NAME),)
LUA_PKG_NAME = $(shell pkg-config --exists lua51 && echo lua51)
endif

ifeq ($(LUA_PKG_NAME),)
$(error Unable to determine lua pkg-config name, specify manually with \
`LUA_PKG_NAME=<name> make`, use `pkg-config --list-all | grep lua` to \
find the correct package name for your system. Please also check that you \
have lua >= 5.1 installed)
endif

# Check if user has sqlite3 libs installed.
ifeq ($(shell pkg-config --exists sqlite3 && echo 1),)
$(error Unable to find sqlite3 libs on your system, do you have sqlite3 \
installed?)
endif

# Check if user has webkit-gtk libs installed.
ifeq ($(shell pkg-config --exists webkit-1.0 && echo 1),)
$(error Unable to find webkit-gtk libs on your system, do you have \
webkit-gtk installed?)
endif

# Generate includes and libs
PKGS := gtk+-2.0 gthread-2.0 webkit-1.0 $(LUA_PKG_NAME) sqlite3 unique-1.0
INCS := $(shell pkg-config --cflags $(PKGS)) -I./
LIBS := $(shell pkg-config --libs $(PKGS))

# Should we load relative config paths first?
ifneq ($(DEVELOPMENT_PATHS),0)
CPPFLAGS += -DDEVELOPMENT_PATHS
endif

# Add flags
CPPFLAGS := -DVERSION=\"$(VERSION)\" $(CPPFLAGS)
CFLAGS   := -std=gnu99 -ggdb -W -Wall -Wextra $(INCS) $(CFLAGS)
LDFLAGS  := $(LIBS) $(LDFLAGS) -Wl,--export-dynamic

# Building on OSX
# TODO: These lines have never been tested
#CFLAGS  += -lgthread-2.0
#LDFLAGS += -pthread

# Building on FreeBSD (or just use gmake)
# TODO: These lines have never been tested
#VERSION != echo `./build-utils/getversion.sh`
#INCS    != echo -I. -I/usr/include `pkg-config --cflags $(PKGS)`
#LIBS    != echo -L/usr/lib `pkg-config --libs $(PKGS)`

# Custom compiler / linker
#CC = clang
