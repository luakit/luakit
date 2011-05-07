# Include makefile config
include config.mk

# Token lib generation
TLIST = common/tokenize.list
THEAD = common/tokenize.h
TSRC  = common/tokenize.c

SRCS  = $(filter-out $(TSRC),$(wildcard *.c) $(wildcard common/*.c) $(wildcard clib/*.c) $(wildcard clib/soup/*.c) $(wildcard widgets/*.c)) $(TSRC)
HEADS = $(wildcard *.h) $(wildcard common/*.h) $(wildcard widgets/*.h) $(wildcard clib/*.h) $(wildcard clib/soup/*.h) $(THEAD) globalconf.h
OBJS  = $(foreach obj,$(SRCS:.c=.o),$(obj))

all: options newline luakit luakit.1

options:
	@echo luakit build options:
	@echo "CC           = $(CC)"
	@echo "LUA_PKG_NAME = $(LUA_PKG_NAME)"
	@echo "CFLAGS       = $(CFLAGS)"
	@echo "CPPFLAGS     = $(CPPFLAGS)"
	@echo "LDFLAGS      = $(LDFLAGS)"
	@echo "INSTALLDIR   = $(INSTALLDIR)"
	@echo "MANPREFIX    = $(MANPREFIX)"
	@echo "DOCDIR       = $(DOCDIR)"
	@echo
	@echo build targets:
	@echo "SRCS  = $(SRCS)"
	@echo "HEADS = $(HEADS)"
	@echo "OBJS  = $(OBJS)"

$(THEAD) $(TSRC): $(TLIST)
	./build-utils/gentokens.lua $(TLIST) $@

globalconf.h: globalconf.h.in
	sed 's#LUAKIT_INSTALL_PATH .*#LUAKIT_INSTALL_PATH "$(PREFIX)/share/luakit"#' globalconf.h.in > globalconf.h

$(OBJS): $(HEADS) config.mk

.c.o:
	@echo $(CC) -c $< -o $@
	@$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

luakit: $(OBJS)
	@echo $(CC) -o $@ $(OBJS)
	@$(CC) -o $@ $(OBJS) $(LDFLAGS)

luakit.1: luakit
	help2man -N -o $@ ./$<

apidoc: luadoc/luakit.lua
	mkdir -p apidocs
	luadoc --nofiles -d apidocs luadoc/* lib/*

doc: globalconf.h $(THEAD) $(TSRC)
	doxygen -s luakit.doxygen

clean:
	rm -rf apidocs doc luakit $(OBJS) $(TSRC) $(THEAD) globalconf.h luakit.1

install:
	install -d $(INSTALLDIR)/share/luakit/
	install -d $(DOCDIR)
	install -m644 README.md AUTHORS COPYING* $(DOCDIR)
	cp -r lib $(INSTALLDIR)/share/luakit/
	chmod 755 $(INSTALLDIR)/share/luakit/lib/
	chmod 755 $(INSTALLDIR)/share/luakit/lib/lousy/
	chmod 755 $(INSTALLDIR)/share/luakit/lib/lousy/widget/
	chmod 644 $(INSTALLDIR)/share/luakit/lib/*.lua
	chmod 644 $(INSTALLDIR)/share/luakit/lib/lousy/*.lua
	chmod 644 $(INSTALLDIR)/share/luakit/lib/lousy/widget/*.lua
	install -d $(INSTALLDIR)/bin
	install luakit $(INSTALLDIR)/bin/luakit
	install -d $(DESTDIR)/etc/xdg/luakit/
	install config/*.lua $(DESTDIR)/etc/xdg/luakit/
	chmod 644 $(DESTDIR)/etc/xdg/luakit/*.lua
	install -d $(DESTDIR)/usr/share/pixmaps
	install extras/luakit.png $(DESTDIR)/usr/share/pixmaps/
	install -d $(DESTDIR)/usr/share/applications
	install extras/luakit.desktop $(DESTDIR)/usr/share/applications/
	install -d $(MANPREFIX)/man1/
	install -m644 luakit.1 $(MANPREFIX)/man1/

uninstall:
	rm -rf $(INSTALLDIR)/bin/luakit $(INSTALLDIR)/share/luakit $(MANPREFIX)/man1/luakit.1
	rm -rf /usr/share/applications/luakit.desktop /usr/share/pixmaps/luakit.png

newline: options;@echo
.PHONY: all clean options install newline apidoc doc
