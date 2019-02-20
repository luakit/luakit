/*
 * clib/widget.c - widget managing
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

#include "clib/widget.h"
#include "common/property.h"

static property_t widget_properties[] = {
  { L_TK_MARGIN,            "margin",            INT,    TRUE  },
  { L_TK_MARGIN_TOP,        "margin-top",        INT,    TRUE  },
  { L_TK_MARGIN_BOTTOM,     "margin-bottom",     INT,    TRUE  },
  { L_TK_MARGIN_LEFT,       "margin-left",       INT,    TRUE  },
  { L_TK_MARGIN_RIGHT,      "margin-right",      INT,    TRUE  },
  { L_TK_CAN_FOCUS,         "can-focus",         BOOL,   TRUE  },
  { 0,                      NULL,                0,      0     },
};

static widget_info_t widgets_list[] = {
  { L_TK_ENTRY,     "entry",    widget_entry    },
  { L_TK_EVENTBOX,  "eventbox", widget_eventbox },
  { L_TK_HBOX,      "hbox",     widget_box      },
  { L_TK_HPANED,    "hpaned",   widget_paned    },
  { L_TK_LABEL,     "label",    widget_label    },
  { L_TK_NOTEBOOK,  "notebook", widget_notebook },
  { L_TK_VBOX,      "vbox",     widget_box      },
  { L_TK_VPANED,    "vpaned",   widget_paned    },
  { L_TK_WEBVIEW,   "webview",  widget_webview  },
  { L_TK_WINDOW,    "window",   widget_window   },
  { L_TK_OVERLAY,   "overlay",  widget_overlay  },
  { L_TK_SCROLLED,  "scrolled", widget_scrolled },
  { L_TK_IMAGE,     "image",    widget_image    },
  { L_TK_SPINNER,   "spinner",  widget_spinner  },
  { L_TK_DRAWING_AREA, "drawing_area", widget_drawing_area },
  { L_TK_STACK,     "stack",    widget_stack    },
};

LUA_OBJECT_FUNCS(widget_class, widget_t, widget);

/** Collect a widget structure.
 * \param L The Lua VM state.
 * \return 0
 */
static gint
luaH_widget_gc(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    if (w->info)
        debug("collecting widget at %p of type '%s'", w, w->info->name);
    g_assert(!w->destructor);
    return luaH_object_gc(L);
}

/** Create a new widget.
 * \param L The Lua VM state.
 *
 * \luastack
 * \lparam A table with at least a type value.
 * \lreturn A brand new widget.
 */
gint
luaH_widget_new(lua_State *L)
{
    luaH_class_new(L, &widget_class);
    widget_t *w = lua_touserdata(L, -1);

    if (!w->info) {
        lua_pop(L, 1); /* Allow garbage collection */
        luaL_error(L, "widget does not have a type");
    }

    /* save ref to the lua class instance */
    lua_pushvalue(L, -1);
    w->ref = luaH_object_ref_class(L, -1, &widget_class);

    return 1;
}

#if GTK_CHECK_VERSION(3,16,0)
static inline void
widget_set_css(widget_t *w, const gchar *properties)
{
    gchar *old_css = gtk_css_provider_to_string(w->provider);
    gchar *css = g_strdup_printf("%s\n#widget { %s }", old_css, properties);
    gtk_css_provider_load_from_data(w->provider, css, strlen(css), NULL);
    g_free(css);
    g_free(old_css);
}

void
widget_set_css_properties(widget_t *w, ...)
{
    va_list argp;
    va_start(argp, w);

    gchar *css = g_strdup("");
    const gchar *prop;
    while ((prop = va_arg(argp, gchar *))) {
        const gchar *value = va_arg(argp, gchar *);
        g_assert(strlen(prop) > 0);
        if (!value || strlen(value) == 0)
            continue;

        gchar *tmp = css;
        css = g_strdup_printf("%s%s: %s;", css, prop, value);
        g_free(tmp);

    }
    va_end(argp);
    widget_set_css(w, css);
    g_free(css);
}
#endif

/** Generic widget.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 * \luastack
 * \lfield visible The widget visibility.
 * \lfield mouse_enter A function to execute when the mouse enter the widget.
 * \lfield mouse_leave A function to execute when the mouse leave the widget.
 */
static gint
luaH_widget_index(lua_State *L)
{
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    /* Try standard method */
    if(luaH_class_index(L))
        return 1;

    if (token == L_TK_IS_ALIVE) {
        widget_t *w = luaH_checkudata(L, 1, &widget_class);
        lua_pushboolean(L, !!w);
        return 1;
    }

    /* Then call special widget index */
    gint ret;
    widget_t *widget = luaH_checkwidget(L, 1);

    /* but only if it's not a GtkWidget property */
    if ((ret = luaH_gobject_index(L, widget_properties, token,
                    G_OBJECT(widget->widget)))) {
        return ret;
    }

    return widget->index ? widget->index(L, widget, token) : 0;
}

/** Generic widget newindex.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 */
static gint
luaH_widget_newindex(lua_State *L)
{
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    /* Try standard method */
    luaH_class_newindex(L);

    /* Then call special widget newindex */
    widget_t *widget = luaH_checkwidget(L, 1);

#if GTK_CHECK_VERSION(3,16,0)
    if (token == L_TK_CSS) {
        widget_set_css(widget, luaL_checkstring(L, 3));
        return 0;
    }
#endif

    /* but only if it's not a GtkWidget property */
    gboolean emit = luaH_gobject_newindex(L, widget_properties, token, 3,
            G_OBJECT(widget->widget));
    if (emit)
        return luaH_object_property_signal(L, 1, token);
    return widget->newindex ? widget->newindex(L, widget, token) : 0;
}

static gint
luaH_widget_set_type(lua_State *L, widget_t *w)
{
    if (w->info)
        luaL_error(L, "widget is already of type: %s", w->info->name);

    const gchar *type = luaL_checkstring(L, -1);
    luakit_token_t tok = l_tokenize(type);
    widget_info_t *winfo;

#if GTK_CHECK_VERSION(3,16,0)
    w->provider = gtk_css_provider_new();
#endif

    for (guint i = 0; i < LENGTH(widgets_list); i++) {
        if (widgets_list[i].tok != tok)
            continue;

        winfo = &widgets_list[i];
        w->info = winfo;
        winfo->wc(L, w, tok);

#if GTK_CHECK_VERSION(3,16,0)
    gtk_widget_set_name(GTK_WIDGET(w->widget), "widget");
    GtkStyleContext *context = gtk_widget_get_style_context(GTK_WIDGET(w->widget));
    gtk_style_context_add_provider(context, GTK_STYLE_PROVIDER(w->provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
#endif

        /* store pointer to lua widget struct in gobject data */
        g_object_set_data(G_OBJECT(w->widget),
            GOBJECT_LUAKIT_WIDGET_DATA_KEY, (gpointer)w);

        verbose("created widget of type: %s", w->info->name);

        lua_pushvalue(L, -3);
        luaH_class_emit_signal(L, &widget_class, "create", 1, 0);
        return 0;
    }

    luaL_error(L, "unknown widget type: %s", type);
    return 0;
}

static gint
luaH_widget_get_type(lua_State *L, widget_t *w)
{
    if (!w->info)
        return 0;

    luaH_checkwidget(L, 1);
    lua_pushstring(L, w->info->name);
    return 1;
}

void
widget_class_setup(lua_State *L)
{
    static const struct luaL_Reg widget_methods[] =
    {
        LUA_CLASS_METHODS(widget)
        { "__call", luaH_widget_new },
        { NULL, NULL }
    };

    static const struct luaL_Reg widget_meta[] =
    {
        LUA_OBJECT_META(widget)
        { "__index", luaH_widget_index },
        { "__newindex", luaH_widget_newindex },
        { "__gc", luaH_widget_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &widget_class, "widget",
            (lua_class_allocator_t) widget_new,
            NULL, NULL,
            widget_methods, widget_meta);

    luaH_class_add_property(&widget_class, L_TK_TYPE,
            (lua_class_propfunc_t) luaH_widget_set_type,
            (lua_class_propfunc_t) luaH_widget_get_type,
            NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
