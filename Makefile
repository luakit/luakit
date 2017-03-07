# Include makefile config
include config.mk

# Token lib generation
TLIST = common/tokenize.list
THEAD = common/tokenize.h
TSRC  = common/tokenize.c

SRCS  = $(filter-out $(TSRC),$(wildcard *.c) $(wildcard common/*.c) $(wildcard common/clib/*.c) $(wildcard clib/*.c) $(wildcard clib/soup/*.c) $(wildcard widgets/*.c)) $(TSRC)
HEADS = $(wildcard *.h) $(wildcard common/*.h) $(wildcard common/clib/*.h) $(wildcard widgets/*.h) $(wildcard clib/*.h) $(wildcard clib/soup/*.h) $(THEAD) buildopts.h
OBJS  = $(foreach obj,$(SRCS:.c=.o),$(obj))

EXT_SRCS = $(filter-out $(TSRC),$(wildcard extension/*.c) $(wildcard extension/clib/*.c) $(wildcard common/*.c)) $(wildcard common/clib/*.c) $(TSRC)
EXT_OBJS = $(foreach obj,$(EXT_SRCS:.c=.o),$(obj))

all: options newline luakit luakit.1.gz luakit.so

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
	@echo "SRCS     = $(SRCS)"
	@echo "HEADS    = $(HEADS)"
	@echo "OBJS     = $(OBJS)"
	@echo "EXT_SRCS = $(EXT_SRCS)"
	@echo "EXT_OBJS = $(EXT_OBJS)"

$(THEAD) $(TSRC): $(TLIST)
	./build-utils/gentokens.lua $(TLIST) $@

buildopts.h: buildopts.h.in
	sed 's#LUAKIT_INSTALL_PATH .*#LUAKIT_INSTALL_PATH "$(PREFIX)/share/luakit"#' buildopts.h.in > buildopts.h

$(filter-out $(EXT_OBJS),$(OBJS)) $(EXT_OBJS): $(HEADS) config.mk

$(filter-out $(EXT_OBJS),$(OBJS)) : %.o : %.c
	@echo $(CC) -c $< -o $@
	@$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

$(EXT_OBJS) : %.o : %.c
	@echo $(CC) -c $< -o $@
	@$(CC) -c $(CFLAGS) -DLUAKIT_WEB_EXTENSION -fpic $(CPPFLAGS) $< -o $@

widgets/webview.o: $(wildcard widgets/webview/*.c)

luakit: $(OBJS)
	@echo $(CC) -o $@ $(OBJS)
	@$(CC) -o $@ $(OBJS) $(LDFLAGS)

luakit.so: $(EXT_OBJS)
	@echo $(CC) -o $@ $(EXT_OBJS)
	@$(CC) -o $@ $(EXT_OBJS) -shared $(LDFLAGS)

luakit.1: luakit.1.in
	@sed "s/LUAKITVERSION/$(VERSION)/" $< > $@

luakit.1.gz: luakit.1
	@gzip -c $< > $@

apidoc:
	rm -rf doc/apidocs
	mkdir doc/apidocs
	ldoc -c doc/config.ld .
	@# Seems to be necessary to prevent WebKitNetworkProcess from crashing - hilarious
	@echo "Replacing DOCTYPE..."
	@find doc/apidocs -iname '*.html' | xargs sed -i -e '1,2d' -e '3s/^/<!DOCTYPE html>\n/'

doc: buildopts.h $(THEAD) $(TSRC)
	doxygen -s doc/luakit.doxygen

clean:
	rm -rf doc/apidocs doc/html luakit $(OBJS) $(EXT_OBJS) $(TSRC) $(THEAD) buildopts.h luakit.1

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
	install luakit.so $(INSTALLDIR)/share/luakit/luakit.so
	install -d $(INSTALLDIR)/bin
	install luakit $(INSTALLDIR)/bin/luakit
	install -d $(DESTDIR)/etc/xdg/luakit/
	install config/*.lua $(DESTDIR)/etc/xdg/luakit/
	chmod 644 $(DESTDIR)/etc/xdg/luakit/*.lua
	install -d $(DESTDIR)/usr/share/pixmaps
	install -m0644 extras/luakit.png $(DESTDIR)/usr/share/pixmaps/
	install -d $(DESTDIR)/usr/share/applications
	install -m0644 extras/luakit.desktop $(DESTDIR)/usr/share/applications/
	install -d $(MANPREFIX)/man1/
	install -m644 luakit.1.gz $(MANPREFIX)/man1/

uninstall:
	rm -rf $(INSTALLDIR)/bin/luakit $(INSTALLDIR)/share/luakit $(MANPREFIX)/man1/luakit.1
	rm -rf /usr/share/applications/luakit.desktop /usr/share/pixmaps/luakit.png

lunit:
	git clone git://repo.or.cz/lunit.git

run-tests: luakit luakit.so lunit
	@luajit tests/run_test.lua

newline: options;@echo
.PHONY: all clean options install newline apidoc doc
