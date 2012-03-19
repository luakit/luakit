/*
 * widgets/notebook.c - gtk notebook widget
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
luaH_notebook_current(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gint n = gtk_notebook_get_n_pages(GTK_NOTEBOOK(w->widget));
    if (n == 1)
        lua_pushnumber(L, 1);
    else
        lua_pushnumber(L, gtk_notebook_get_current_page(
            GTK_NOTEBOOK(w->widget)) + 1);
    return 1;
}

static gint
luaH_notebook_atindex(lua_State *L, widget_t *w, gint idx)
{
    /* correct index */
    if (idx != -1) idx--;

    GtkWidget *widget = gtk_notebook_get_nth_page(GTK_NOTEBOOK(w->widget), idx);
    if (!widget)
        return 0;

    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    luaH_object_push(L, child->ref);
    return 1;
}

static gint
luaH_notebook_indexof(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gint i = gtk_notebook_page_num(GTK_NOTEBOOK(w->widget), child->widget);
    /* return index or nil */
    if (!++i) return 0;
    lua_pushnumber(L, i);
    return 1;
}

static gint
luaH_notebook_remove(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gint i = gtk_notebook_page_num(GTK_NOTEBOOK(w->widget), child->widget);

    if (i == -1)
        luaL_argerror(L, 2, "child not in notebook");

    GtkWidget *widget = gtk_notebook_get_nth_page(GTK_NOTEBOOK(w->widget), i);
    g_object_ref(G_OBJECT(widget));
    gtk_notebook_remove_page(GTK_NOTEBOOK(w->widget), i);
    return 0;
}

/* Inserts a widget into the notebook widget at an index */
static gint
luaH_notebook_insert(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);

    /* get insert position (or append page) */
    gint pos = -1, idx = 2;
    if (lua_gettop(L) > 2) {
        pos = luaL_checknumber(L, idx++);
        if (pos > 0) pos--; /* correct lua index */
    }

    pos = gtk_notebook_insert_page(GTK_NOTEBOOK(w->widget),
        GTK_WIDGET(luaH_checkwidget(L, idx)->widget), NULL, pos);

    /* failed to insert page */
    if (pos == -1)
        return 0;

    /* return new (lua corrected) index */
    lua_pushnumber(L, ++pos);
    return 1;
}

/* Return the number of widgets in the notebook */
static gint
luaH_notebook_count(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    lua_pushnumber(L, gtk_notebook_get_n_pages(GTK_NOTEBOOK(w->widget)));
    return 1;
}

static gint
luaH_notebook_set_title(lua_State *L)
{
    size_t len;
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    const gchar *title = luaL_checklstring(L, 3, &len);
    gtk_notebook_set_tab_label_text(GTK_NOTEBOOK(w->widget),
        child->widget, title);
    return 0;
}

static gint
luaH_notebook_get_title(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    lua_pushstring(L, gtk_notebook_get_tab_label_text(
        GTK_NOTEBOOK(w->widget), child->widget));
    return 1;
}

static gint
luaH_notebook_switch(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gint i = luaL_checknumber(L, 2);
    /* correct index */
    if (i != -1) i--;
    gtk_notebook_set_current_page(GTK_NOTEBOOK(w->widget), i);
    lua_pushnumber(L, gtk_notebook_get_current_page(GTK_NOTEBOOK(w->widget)));
    return 1;
}

static gint
luaH_notebook_reorder(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gint i = luaL_checknumber(L, 3);
    /* correct lua index */
    if (i != -1) i--;
    gtk_notebook_reorder_child(GTK_NOTEBOOK(w->widget), child->widget, i);
    lua_pushnumber(L, gtk_notebook_page_num(GTK_NOTEBOOK(w->widget), child->widget));
    return 1;
}

static gint
luaH_notebook_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    /* handle numerical index lookups */
    if (token == L_TK_UNKNOWN && lua_isnumber(L, 2))
        return luaH_notebook_atindex(L, w, (gint)luaL_checknumber(L, 2));

    switch(token)
    {
      LUAKIT_WIDGET_INDEX_COMMON(w)

      /* push class methods */
      PF_CASE(COUNT,        luaH_notebook_count)
      PF_CASE(CURRENT,      luaH_notebook_current)
      PF_CASE(GET_TITLE,    luaH_notebook_get_title)
      PF_CASE(INDEXOF,      luaH_notebook_indexof)
      PF_CASE(INSERT,       luaH_notebook_insert)
      PF_CASE(REMOVE,       luaH_notebook_remove)
      PF_CASE(SET_TITLE,    luaH_notebook_set_title)
      PF_CASE(SWITCH,       luaH_notebook_switch)
      PF_CASE(REORDER,      luaH_notebook_reorder)

      case L_TK_CHILDREN:
        return luaH_widget_get_children(L, w);

      /* push boolean properties */
      PB_CASE(SHOW_TABS,    gtk_notebook_get_show_tabs(GTK_NOTEBOOK(w->widget)))
      PB_CASE(SHOW_BORDER,  gtk_notebook_get_show_border(GTK_NOTEBOOK(w->widget)))

      default:
        break;
    }
    return 0;
}

static gint
luaH_notebook_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

      case L_TK_SHOW_TABS:
        gtk_notebook_set_show_tabs(GTK_NOTEBOOK(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_SHOW_BORDER:
        gtk_notebook_set_show_border(GTK_NOTEBOOK(w->widget), luaH_checkboolean(L, 3));
        break;

      default:
        return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

static void
page_added_cb(GtkNotebook* UNUSED(n), GtkWidget *widget, guint i, widget_t *w)
{
    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    lua_pushnumber(L, i + 1);
    luaH_object_emit_signal(L, -3, "page-added", 2, 0);
    lua_pop(L, 1);
}

static void
page_removed_cb(GtkNotebook* UNUSED(n), GtkWidget *widget, guint UNUSED(i),
        widget_t *w)
{
    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -2, "page-removed", 1, 0);
    lua_pop(L, 1);
}

static void
switch_cb(GtkNotebook *n, GtkNotebookPage* UNUSED(p), guint i, widget_t *w)
{
    GtkWidget *widget = gtk_notebook_get_nth_page(GTK_NOTEBOOK(n), i);
    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    lua_pushnumber(L, i + 1);
    luaH_object_emit_signal(L, -3, "switch-page", 2, 0);
    lua_pop(L, 1);
}

static void
reorder_cb(GtkNotebook* UNUSED(n), GtkWidget *widget, guint i, widget_t *w)
{
    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    lua_pushnumber(L, i + 1);
    luaH_object_emit_signal(L, -3, "page-reordered", 2, 0);
    lua_pop(L, 1);
}

widget_t *
widget_notebook(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_notebook_index;
    w->newindex = luaH_notebook_newindex;
    w->destructor = widget_destructor;

    /* create and setup notebook widget */
    w->widget = gtk_notebook_new();
    gtk_notebook_set_show_border(GTK_NOTEBOOK(w->widget), FALSE);
    gtk_notebook_set_scrollable(GTK_NOTEBOOK(w->widget), TRUE);

    g_object_connect(G_OBJECT(w->widget),
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      "signal::key-press-event",   G_CALLBACK(key_press_cb),    w,
      "signal::page-added",        G_CALLBACK(page_added_cb),   w,
      "signal::page-removed",      G_CALLBACK(page_removed_cb), w,
      "signal::page-reordered",    G_CALLBACK(reorder_cb),      w,
      "signal::switch-page",       G_CALLBACK(switch_cb),       w,
      NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
