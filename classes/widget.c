/*
 * widget.c - widget managing
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

#include "classes/widget.h"

widget_info_t widgets_list[] = {
  { L_TK_ENTRY,      "entry",      widget_entry      },
  { L_TK_EVENTBOX,   "eventbox",   widget_eventbox   },
  { L_TK_HBOX,       "hbox",       widget_hbox       },
  { L_TK_LABEL,      "label",      widget_label      },
  { L_TK_NOTEBOOK,   "notebook",   widget_notebook   },
  { L_TK_VBOX,       "vbox",       widget_vbox       },
  { L_TK_WEBVIEW,    "webview",    widget_webview    },
  { L_TK_WINDOW,     "window",     widget_window     },
  { L_TK_UNKNOWN,    NULL,         NULL              }
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
    debug("collecting widget at %p of type '%s'", w, w->info->name);
    if(w->destructor)
        w->destructor(w);
    return luaH_object_gc(L);
}

/** Create a new widget.
 * \param L The Lua VM state.
 *
 * \luastack
 * \lparam A table with at least a type value.
 * \lreturn A brand new widget.
 */
static gint
luaH_widget_new(lua_State *L)
{
    luaH_class_new(L, &widget_class);
    widget_t *w = luaH_checkudata(L, -1, &widget_class);

    /* save ref to the lua class instance */
    lua_pushvalue(L, -1);
    w->ref = luaH_object_ref_class(L, -1, &widget_class);

    return 1;
}

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

    /* Then call special widget index */
    widget_t *widget = luaH_checkudata(L, 1, &widget_class);
    return widget->index ? widget->index(L, token) : 0;
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
    widget_t *widget = luaH_checkudata(L, 1, &widget_class);
    return widget->newindex ? widget->newindex(L, token) : 0;
}

static gint
luaH_widget_set_type(lua_State *L, widget_t *w)
{
    if (w->info)
        luaL_error(L, "widget is already of type: %s", w->info->name);

    const gchar *type = luaL_checkstring(L, -1);
    luakit_token_t tok = l_tokenize(type);
    widget_info_t *winfo;

    for (guint i = 0; i < LENGTH(widgets_list); i++)
    {
        if (widgets_list[i].tok != tok)
            continue;

        winfo = &widgets_list[i];
        w->info = winfo;
        winfo->wc(w);
        luaH_object_emit_signal(L, -3, "init", 0, 0);
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

    lua_pushstring(L, w->info->name);
    return 1;
}

void
widget_class_setup(lua_State *L)
{
    static const struct luaL_reg widget_methods[] =
    {
        LUA_CLASS_METHODS(widget)
        { "__call", luaH_widget_new },
        { NULL, NULL }
    };

    static const struct luaL_reg widget_meta[] =
    {
        LUA_OBJECT_META(widget)
        { "__index", luaH_widget_index },
        { "__newindex", luaH_widget_newindex },
        { "__gc", luaH_widget_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &widget_class, "widget", (lua_class_allocator_t) widget_new,
                     NULL, NULL,
                     widget_methods, widget_meta);

    luaH_class_add_property(&widget_class, L_TK_TYPE,
                            (lua_class_propfunc_t) luaH_widget_set_type,
                            (lua_class_propfunc_t) luaH_widget_get_type,
                            NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
