/*
 * textbutton.c - gtk button with label
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2007-2009 Julien Danjou <julien@danjou.info>
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

#include "widgets/common.h"
#include "luah.h"
#include "widget.h"

typedef struct
{
    /* gtk button widget */
    GtkWidget *button;
    /* label text */
    gchar *label;
} textbutton_data_t;

static gint
luaH_textbutton_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    textbutton_data_t *d = w->data;

    switch (token)
    {
      case L_TK_LABEL:
        if (!d->label) return 0;
        lua_pushstring(L, d->label);
        return 1;

      default:
        break;
    }
    return 0;
}

static gint
luaH_textbutton_newindex(lua_State *L, luakit_token_t token)
{
    size_t len;
    gchar *tmp;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    textbutton_data_t *d = w->data;

    switch(token)
    {
      case L_TK_LABEL:
        tmp = (gchar *) luaL_checklstring(L, 3, &len);
        if (d->label)
            g_free(d->label);
        d->label = g_strdup(tmp);
        gtk_button_set_label(GTK_BUTTON(d->button), d->label);
        break;

      default:
        return 0;
    }

    tmp = g_strdup_printf("property::%s", luaL_checklstring(L, 2, &len));
    luaH_object_emit_signal(L, 1, tmp, 0, 0);
    g_free(tmp);
    return 0;
}

void
clicked_cb(GtkWidget *b, widget_t *w)
{
    (void) b;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "clicked", 0, 0);
    lua_pop(L, 1);
}

static void
textbutton_destructor(widget_t *w)
{
    if (!w->data)
        return;

    textbutton_data_t *d = w->data;
    gtk_widget_destroy(d->button);
    g_free(d->label);
    g_free(d);
}

widget_t *
widget_textbutton(widget_t *w)
{
    w->index = luaH_textbutton_index;
    w->newindex = luaH_textbutton_newindex;
    w->destructor = textbutton_destructor;

    /* create textbutton data struct & gtk widgets */
    textbutton_data_t *d = w->data = g_new0(textbutton_data_t, 1);
    w->widget = d->button = gtk_button_new();

    /* setup default settings */
    gtk_button_set_focus_on_click(GTK_BUTTON(d->button), FALSE);

    g_object_connect((GObject*)d->button,
      "signal::clicked",         (GCallback)clicked_cb, w,
      "signal::focus-in-event",  (GCallback)focus_cb,   w,
      "signal::focus-out-event", (GCallback)focus_cb,   w,
      NULL);

    gtk_widget_show(d->button);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
