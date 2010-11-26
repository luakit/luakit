/*
 * widgets/notebook.c - gtk notebook widget
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
luaH_notebook_atindex(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gint i = luaL_checknumber(L, 2);
    /* correct index */
    if (i != -1) i--;

    GtkWidget *widget = gtk_notebook_get_nth_page(GTK_NOTEBOOK(w->widget), i);
    if (!widget)
        return 0;

    widget_t *child = g_object_get_data(G_OBJECT(widget), "lua_widget");
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
    widget_t *child = luaH_checkwidget(L, 2);
    gint i = luaL_checknumber(L, 3);
    /* correct index */
    if (i != -1) i--;

    i = gtk_notebook_insert_page(GTK_NOTEBOOK(w->widget),
        child->widget, NULL, i);

    /* return new index or nil */
    if (!++i) return 0;
    lua_pushnumber(L, i);
    return 1;
}

/* Appends a widget to the notebook widget */
static gint
luaH_notebook_append(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gint i = gtk_notebook_append_page(GTK_NOTEBOOK(w->widget),
        child->widget, NULL);

    /* return new index or nil */
    if (!++i) return 0;
    lua_pushnumber(L, i);
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
luaH_notebook_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkwidget(L, 1);

    switch(token)
    {
      LUAKIT_WIDGET_INDEX_COMMON

      /* push class methods */
      PF_CASE(APPEND,       luaH_notebook_append)
      PF_CASE(ATINDEX,      luaH_notebook_atindex)
      PF_CASE(COUNT,        luaH_notebook_count)
      PF_CASE(CURRENT,      luaH_notebook_current)
      PF_CASE(GET_TITLE,    luaH_notebook_get_title)
      PF_CASE(INDEXOF,      luaH_notebook_indexof)
      PF_CASE(INSERT,       luaH_notebook_insert)
      PF_CASE(REMOVE,       luaH_notebook_remove)
      PF_CASE(SET_TITLE,    luaH_notebook_set_title)
      PF_CASE(SWITCH,       luaH_notebook_switch)
      PF_CASE(REORDER,      luaH_notebook_reorder)

      /* push container class methods */
      PF_CASE(GET_CHILDREN, luaH_widget_get_children)

      /* push boolean properties */
      PB_CASE(SHOW_TABS,    gtk_notebook_get_show_tabs(GTK_NOTEBOOK(w->widget)))
      PB_CASE(SHOW_BORDER,  gtk_notebook_get_show_border(GTK_NOTEBOOK(w->widget)))

      default:
        break;
    }
    return 0;
}

static gint
luaH_notebook_newindex(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkwidget(L, 1);

    switch(token)
    {
      case L_TK_SHOW_TABS:
        gtk_notebook_set_show_tabs(GTK_NOTEBOOK(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_SHOW_BORDER:
        gtk_notebook_set_show_border(GTK_NOTEBOOK(w->widget), luaH_checkboolean(L, 3));
        break;

      default:
        return 0;
    }

    return luaH_object_emit_property_signal(L, 1);
}

static void
page_added_cb(GtkNotebook *n, GtkWidget *widget, guint i, widget_t *w)
{
    (void) n;

    widget_t *child = g_object_get_data(G_OBJECT(widget), "lua_widget");
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    lua_pushnumber(L, i + 1);
    luaH_object_emit_signal(L, -3, "page-added", 2, 0);
    lua_pop(L, 1);
}

static void
page_removed_cb(GtkNotebook *n, GtkWidget *widget, guint i, widget_t *w)
{
    (void) i;
    (void) n;

    widget_t *child = g_object_get_data(G_OBJECT(widget), "lua_widget");
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -2, "page-removed", 1, 0);
    lua_pop(L, 1);
}

static void
switch_cb(GtkNotebook *n, GtkNotebookPage *p, guint i, widget_t *w)
{
    (void) p;
    GtkWidget *widget = gtk_notebook_get_nth_page(GTK_NOTEBOOK(n), i);
    widget_t *child = g_object_get_data(G_OBJECT(widget), "lua_widget");

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    lua_pushnumber(L, i + 1);
    luaH_object_emit_signal(L, -3, "switch-page", 2, 0);
    lua_pop(L, 1);
}

static void
reorder_cb(GtkNotebook *n, GtkWidget *widget, guint i, widget_t *w)
{
    (void) n;
    widget_t *child = g_object_get_data(G_OBJECT(widget), "lua_widget");

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    lua_pushnumber(L, i + 1);
    luaH_object_emit_signal(L, -3, "page-reordered", 2, 0);
    lua_pop(L, 1);
}

widget_t *
widget_notebook(widget_t *w)
{
    w->index = luaH_notebook_index;
    w->newindex = luaH_notebook_newindex;
    w->destructor = widget_destructor;

    /* create and setup notebook widget */
    w->widget = gtk_notebook_new();
    g_object_set_data(G_OBJECT(w->widget), "lua_widget", (gpointer) w);
    gtk_notebook_set_show_border(GTK_NOTEBOOK(w->widget), FALSE);
    gtk_notebook_set_scrollable(GTK_NOTEBOOK(w->widget), TRUE);

    g_object_connect(G_OBJECT(w->widget),
      "signal::focus-in-event",    G_CALLBACK(focus_cb),        w,
      "signal::focus-out-event",   G_CALLBACK(focus_cb),        w,
      "signal::key-press-event",   G_CALLBACK(key_press_cb),    w,
      "signal::page-added",        G_CALLBACK(page_added_cb),   w,
      "signal::page-removed",      G_CALLBACK(page_removed_cb), w,
      "signal::page-reordered",    G_CALLBACK(reorder_cb),      w,
      "signal::parent-set",        G_CALLBACK(parent_set_cb),   w,
      "signal::switch-page",       G_CALLBACK(switch_cb),       w,
      NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
