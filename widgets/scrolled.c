#include "luah.h"
#include "widgets/common.h"

static gint
luaH_scrolled_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_INDEX_COMMON(w)
      default:
        break;
    }
    return 0;
}

static gint
luaH_scrolled_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_NEWINDEX_COMMON(w)
      default:
        break;;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_scrolled(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_scrolled_index;
    w->newindex = luaH_scrolled_newindex;
    w->destructor = widget_destructor;

#if GTK_CHECK_VERSION(3,2,0)
    w->widget = gtk_scrolled_window_new(NULL, NULL);
#endif

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
