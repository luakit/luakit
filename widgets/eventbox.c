/*
 * widgets/eventbox.c - gtk eventbox widget
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "luah.h"
#include "widgets/common.h"

static gint
luaH_eventbox_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_INDEX_COMMON(w)
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON(w)

      /* push string properties */
      PS_CASE(BG, g_object_get_data(G_OBJECT(w->widget), "bg"))

      default:
        break;
    }
    return 0;
}

static gint
luaH_eventbox_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    size_t len;
    const gchar *tmp;
    GdkColor c;

    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_NEWINDEX_COMMON(w)

      case L_TK_BG:
        tmp = luaL_checklstring(L, 3, &len);
        if (!gdk_color_parse(tmp, &c))
            luaL_argerror(L, 3, "unable to parse colour");
        gtk_widget_modify_bg(GTK_WIDGET(w->widget), GTK_STATE_NORMAL, &c);
        g_object_set_data_full(G_OBJECT(w->widget), "bg", g_strdup(tmp), g_free);
        break;

      default:
        return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_eventbox(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_eventbox_index;
    w->newindex = luaH_eventbox_newindex;
    w->destructor = widget_destructor;

    w->widget = gtk_event_box_new();
    gtk_widget_show(w->widget);

    g_object_connect(G_OBJECT(w->widget),
      "signal::add",                  G_CALLBACK(add_cb),        w,
      "signal::button-press-event",   G_CALLBACK(button_cb),     w,
      "signal::button-release-event", G_CALLBACK(button_cb),     w,
      "signal::parent-set",           G_CALLBACK(parent_set_cb), w,
      "signal::remove",               G_CALLBACK(remove_cb),     w,
      NULL);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
