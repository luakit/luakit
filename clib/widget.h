/*
 * clib/widget.h - widget managing header
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2007-2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_CLIB_WIDGET_H
#define LUAKIT_CLIB_WIDGET_H

typedef struct widget_t widget_t;

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"
#include "luah.h"
#include "globalconf.h"

#include <gtk/gtk.h>

#define GOBJECT_LUAKIT_WIDGET_DATA_KEY "luakit_widget_data"

#define GOBJECT_TO_LUAKIT_WIDGET(gtk_widget) ((widget_t*)g_object_get_data(G_OBJECT(gtk_widget), \
            GOBJECT_LUAKIT_WIDGET_DATA_KEY))

typedef widget_t *(widget_constructor_t)(lua_State *L, widget_t *, luakit_token_t);
typedef void (widget_destructor_t)(widget_t *);

widget_constructor_t widget_box;
widget_constructor_t widget_entry;
widget_constructor_t widget_eventbox;
widget_constructor_t widget_label;
widget_constructor_t widget_notebook;
widget_constructor_t widget_paned;
widget_constructor_t widget_webview;
widget_constructor_t widget_window;
widget_constructor_t widget_overlay;
widget_constructor_t widget_scrolled;
widget_constructor_t widget_image;
widget_constructor_t widget_spinner;
widget_constructor_t widget_drawing_area;
widget_constructor_t widget_stack;

typedef const struct {
    luakit_token_t tok;
    const gchar *name;
    widget_constructor_t *wc;
} widget_info_t;

/* Widget */
struct widget_t
{
    LUA_OBJECT_HEADER
    /* Widget type information */
    widget_info_t *info;
    /* Widget destructor */
    widget_destructor_t *destructor;
    /* Index function */
    gint (*index)(lua_State *, widget_t *, luakit_token_t);
    /* Newindex function */
    gint (*newindex)(lua_State *, widget_t *, luakit_token_t);
    /* Lua object ref */
    gpointer ref;
    /* Main gtk widget */
    GtkWidget *widget;
#if GTK_CHECK_VERSION(3,16,0)
    /* CSS provider for this widget */
    GtkCssProvider *provider;
#endif
    /* Previous width and height, for resize signal */
    gint prev_width, prev_height;
    /* Misc private data */
    gpointer data;
};

extern lua_class_t widget_class;
void widget_class_setup(lua_State *);
void widget_set_css_properties(widget_t *, ...);
gint luaH_widget_new(lua_State *L);

static inline widget_t*
luaH_checkwidget(lua_State *L, gint udx)
{
    widget_t *w = luaH_checkudata(L, udx, &widget_class);
    if (!w->widget)
        luaL_error(L, "widget %p (%s) has been destroyed", w, w->info->name);
    g_assert(GTK_IS_WIDGET(w->widget));
    return w;
}

static inline widget_t*
luaH_checkwidgetornil(lua_State *L, gint udx)
{
    if (lua_isnil(L, udx))
        return NULL;
    return luaH_checkwidget(L, udx);
}

#define luaH_towidget(L, udx) luaH_toudata(L, udx, &widget_class)

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
