#include "luah.h"
#include "widgets/common.h"

static widget_t*
luaH_checkspinner(lua_State *L, gint udx)
{
    widget_t *w = luaH_checkwidget(L, udx);
    if (w->info->tok != L_TK_SPINNER)
        luaL_argerror(L, udx, "incorrect widget type (expected spinner)");
    return w;
}

static gint
luaH_spinner_start(lua_State *L)
{
    widget_t *w = luaH_checkspinner(L, 1);
    gtk_spinner_start(GTK_SPINNER(w->widget));
    return 0;
}

static gint
luaH_spinner_stop(lua_State *L)
{
    widget_t *w = luaH_checkspinner(L, 1);
    gtk_spinner_stop(GTK_SPINNER(w->widget));
    return 0;
}

static gint
luaH_spinner_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    gboolean active;
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)

      PB_CASE(STARTED, (g_object_get(G_OBJECT(w->widget), "active", &active, NULL), active))
      PF_CASE(START, luaH_spinner_start)
      PF_CASE(STOP, luaH_spinner_stop)

      default:
        break;
    }
    return 0;
}

static gint
luaH_spinner_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

      default:
        break;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_spinner(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_spinner_index;
    w->newindex = luaH_spinner_newindex;
    w->destructor = widget_destructor;

    w->widget = gtk_spinner_new();

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
