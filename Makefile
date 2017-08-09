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

# List of sources used to generate Lua API documentation
# Must be kept in sync with doc/docgen.ld
DOC_SRCS = $(filter-out lib/markdown.lua lib/lousy/init.lua,$(shell for d in doc/luadoc lib common/clib; do find $$d -type f; done)) tests/lib.lua

all: options newline luakit luakit.1.gz luakit.so apidoc

options:
	@echo luakit build options:
	@echo "CC           = $(CC)"
	@echo "LUA_PKG_NAME = $(LUA_PKG_NAME)"
	@echo "LUA_BIN_NAME = $(LUA_BIN_NAME)"
	@echo "CFLAGS       = $(CFLAGS)"
	@echo "CPPFLAGS     = $(CPPFLAGS)"
	@echo "LDFLAGS      = $(LDFLAGS)"
	@echo "INSTALLDIR   = $(INSTALLDIR)"
	@echo "MANPREFIX    = $(MANPREFIX)"
	@echo "DOCDIR       = $(DOCDIR)"
	@echo "XDGPREFIX    = $(XDGPREFIX)"
	@echo "PIXMAPDIR    = $(PIXMAPDIR)"
	@echo "APPDIR       = $(APPDIR)"
	@echo
	@echo build targets:
	@echo "SRCS     = $(SRCS)"
	@echo "HEADS    = $(HEADS)"
	@echo "OBJS     = $(OBJS)"
	@echo "EXT_SRCS = $(EXT_SRCS)"
	@echo "EXT_OBJS = $(EXT_OBJS)"

$(THEAD) $(TSRC): $(TLIST)
	$(LUA_BIN_NAME) ./build-utils/gentokens.lua $(TLIST) $@

buildopts.h: buildopts.h.in
	sed -e 's#LUAKIT_INSTALL_PATH .*#LUAKIT_INSTALL_PATH "$(PREFIX)/share/luakit"#' \
		-e 's#LUAKIT_CONFIG_PATH .*#LUAKIT_CONFIG_PATH "$(XDGPREFIX)"#' buildopts.h.in \
		> buildopts.h

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

doc/apidocs/index.html: $(DOC_SRCS) $(wildcard build-utils/docgen/*)
	rm -rf doc/apidocs
	mkdir doc/apidocs
	$(LUA_BIN_NAME) ./build-utils/docgen/makedoc.lua

apidoc: doc/apidocs/index.html

doc: buildopts.h $(THEAD) $(TSRC)
	doxygen -s doc/luakit.doxygen

clean:
	rm -rf doc/apidocs doc/html luakit $(OBJS) $(EXT_OBJS) $(TSRC) $(THEAD) buildopts.h luakit.1 luakit.1.gz luakit.so

install: all
	install -d $(INSTALLDIR)/share/luakit/
	install -d $(DOCDIR) $(DOCDIR)/classes $(DOCDIR)/modules $(DOCDIR)/pages
	install -m644 README.md AUTHORS COPYING.GPLv3 $(DOCDIR)
	install -m644 doc/apidocs/classes/* $(DOCDIR)/classes
	install -m644 doc/apidocs/modules/* $(DOCDIR)/modules
	install -m644 doc/apidocs/pages/* $(DOCDIR)/pages
	install -m644 doc/apidocs/*.html $(DOCDIR)
	install -d $(INSTALLDIR)/share/luakit/lib $(INSTALLDIR)/share/luakit/lib/lousy $(INSTALLDIR)/share/luakit/lib/lousy/widget
	install -m644 lib/*.* $(INSTALLDIR)/share/luakit/lib
	install -m644 lib/lousy/*.* $(INSTALLDIR)/share/luakit/lib/lousy
	install -m644 lib/lousy/widget/*.* $(INSTALLDIR)/share/luakit/lib/lousy/widget
	install -m644 luakit.so $(INSTALLDIR)/share/luakit/luakit.so
	install -d $(INSTALLDIR)/bin
	install luakit $(INSTALLDIR)/bin/luakit
	install -d $(XDGPREFIX)/luakit/
	install -m644 config/*.lua $(XDGPREFIX)/luakit/
	install -d $(PIXMAPDIR)
	install -m644 extras/luakit.png $(PIXMAPDIR)
	install -d $(APPDIR)
	install -m644 extras/luakit.desktop $(APPDIR)
	install -d $(MANPREFIX)/man1/
	install -m644 luakit.1.gz $(MANPREFIX)/man1/
	mkdir -p resources
	find resources -type d -exec install -d $(INSTALLDIR)/share/luakit/'{}' \;
	find resources -type f -exec sh -c 'f="{}"; install -m644 "$$f" "$(INSTALLDIR)/share/luakit/$$(dirname $$f)"' \;

uninstall:
	rm -rf $(INSTALLDIR)/bin/luakit $(INSTALLDIR)/share/luakit
	rm -rf $(MANPREFIX)/man1/luakit.1.gz $(XDGPREFIX)/luakit
	rm -rf $(APPDIR)/luakit.desktop $(PIXMAPDIR)/luakit.png

tests/util.so: tests/util.c Makefile
	$(CC) -fpic $(CFLAGS) $(CPPFLAGS) -shared $< $(LDFLAGS) -o $@

run-tests: luakit luakit.so tests/util.so
	@$(LUA_BIN_NAME) tests/run_test.lua

newline: options;@echo
.PHONY: all clean options install newline apidoc doc default
