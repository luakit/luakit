#ifndef LUAKIT_EXTENSION_SCROLL_H
#define LUAKIT_EXTENSION_SCROLL_H

#include <webkit2/webkit-web-extension.h>

void web_scroll_to(guint64 page_id, gint scroll_x, gint scroll_y);
void web_scroll_init(void);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
