/*
 * notebook.c - gtk notebook widget
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

/* TODO
 *  - In the notebook destructor function detach all child widgets
 *  - Add `get_children()` method which returns a table of the child widgets
 */

#include "luakit.h"
#include "luah.h"
#include "widget.h"

typedef struct
{
    /* gtk notebook widget */
    GtkWidget *nbook;
    /* reverse child widget lookup */
    GHashTable *children;

} notebook_data_t;

static inline void
luaH_notebook_checkindex(lua_State *L, GtkWidget *nbook, gint i)
{
    if (i < 0 || i >= gtk_notebook_get_n_pages(GTK_NOTEBOOK(nbook)))
        luaL_error(L, "invalid notebook index: %d", i + 1);
}

/* return the child widget at the given index */
widget_t *
notebook_atindex(lua_State *L, widget_t *w, gint i)
{
    notebook_data_t *d = w->data;
    luaH_notebook_checkindex(L, d->nbook, i);
    gpointer widget = gtk_notebook_get_nth_page(GTK_NOTEBOOK(d->nbook), i);
    /* reverse lookup child widget */
    return g_hash_table_lookup(d->children, widget);
}

/* return the child widget of the current page */
static gint
luaH_notebook_current(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    notebook_data_t *d = w->data;

    gint i = gtk_notebook_get_current_page(GTK_NOTEBOOK(d->nbook));
    if (i == -1)
        return 0;

    widget_t *child = notebook_atindex(L, w, i);
    return luaH_object_push(L, child->ref);
}

/* return the index of the child widget in the gtk notebook */
static gint
luaH_notebook_indexof(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    notebook_data_t *d = w->data;
    widget_t *child = luaH_checkudata(L, 2, &widget_class);

    if (!child->parent || child->parent != w)
        luaL_error(L, "widget not in this notebook");

    gint i = gtk_notebook_page_num(GTK_NOTEBOOK(d->nbook), child->widget);
    lua_pushnumber(L, ++i);
    return 1;
}

/* Remove a widget from the notebook widget */
static gint
luaH_notebook_remove(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    notebook_data_t *d = w->data;
    widget_t *child = luaH_widget_checkgtk(L,
            luaH_checkudata(L, 2, &widget_class));

    if (!child->parent || child->parent != w)
        luaL_error(L, "widget not in this notebook");

    gint i = gtk_notebook_page_num(GTK_NOTEBOOK(d->nbook), child->widget);
    gtk_notebook_remove_page(GTK_NOTEBOOK(d->nbook), i);

    return 0;
}

/* Generic function to insert a widget into the notebook widget */
static gint
notebook_insert(lua_State *L, widget_t *w, widget_t *child, gint i)
{
    notebook_data_t *d = w->data;

    luaH_widget_checkgtk(L, w);
    luaH_widget_checkgtk(L, child);

    if (child->parent || child->window)
        luaL_error(L, "widget already has parent window");

    /* add reverse widget lookup by gtk widget */
    g_hash_table_insert(d->children, child->widget, child);
    child->parent = w;

    gint ret = gtk_notebook_insert_page(GTK_NOTEBOOK(d->nbook),
            GTK_WIDGET(child->widget), NULL, i);

    /* return tab index */
    lua_pushnumber(L, ret);
    return 1;
}

/* Inserts a widget into the notebook widget at an index */
static gint
luaH_notebook_insert(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    notebook_data_t *d = w->data;
    /* get index */
    gint i = luaL_checknumber(L, 2);
    if (i != -1)
        i--;
    luaH_notebook_checkindex(L, d->nbook, i);
    widget_t *child = luaH_checkudata(L, 3, &widget_class);
    return notebook_insert(L, w, child, i);
}

/* Appends a widget to the notebook widget */
static gint
luaH_notebook_append(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    widget_t *child = luaH_checkudata(L, 2, &widget_class);
    return notebook_insert(L, w, child, -1);
}

/* Return the number of widgets in the notebook */
static gint
luaH_notebook_count(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    notebook_data_t *d = w->data;
    lua_pushnumber(L, gtk_notebook_get_n_pages(GTK_NOTEBOOK(d->nbook)));
    return 1;
}

static gint
luaH_notebook_set_title(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    notebook_data_t *d = w->data;
    widget_t *child = luaH_checkudata(L, 2, &widget_class);
    size_t len;
    const gchar *title = luaL_checklstring(L, 3, &len);
    gtk_notebook_set_tab_label_text(GTK_NOTEBOOK(d->nbook),
            child->widget, title);
    return 0;
}

static gint
luaH_notebook_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    notebook_data_t *d = w->data;

    switch(token)
    {
      case L_TK_COUNT:
        lua_pushcfunction(L, luaH_notebook_count);
        return 1;

      case L_TK_INSERT:
        lua_pushcfunction(L, luaH_notebook_insert);
        return 1;

      case L_TK_APPEND:
        lua_pushcfunction(L, luaH_notebook_append);
        return 1;

      case L_TK_CURRENT:
        lua_pushcfunction(L, luaH_notebook_current);
        return 1;

      case L_TK_REMOVE:
        lua_pushcfunction(L, luaH_notebook_remove);
        return 1;

      case L_TK_INDEXOF:
        lua_pushcfunction(L, luaH_notebook_indexof);
        return 1;

      case L_TK_SET_TITLE:
        lua_pushcfunction(L, luaH_notebook_set_title);
        return 1;

      case L_TK_SHOW_TABS:
        lua_pushboolean(L,
                gtk_notebook_get_show_tabs(GTK_NOTEBOOK(d->nbook)));
        return 1;

      case L_TK_SHOW_BORDER:
        lua_pushboolean(L,
                gtk_notebook_get_show_border(GTK_NOTEBOOK(d->nbook)));
        return 1;

      default:
        break;
    }
    return 0;
}

static gint
luaH_notebook_newindex(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    notebook_data_t *d = w->data;

    switch(token)
    {
      case L_TK_SHOW_TABS:
        gtk_notebook_set_show_tabs(GTK_NOTEBOOK(d->nbook),
                luaH_checkboolean(L, -1));
        break;

      case L_TK_SHOW_BORDER:
        gtk_notebook_set_show_border(GTK_NOTEBOOK(d->nbook),
                luaH_checkboolean(L, -1));
        break;

      default:
        break;
    }
    return 0;
}

void
page_added_cb(GtkNotebook *nbook, GtkWidget *widget, guint i, widget_t *w)
{
    (void) i;
    (void) nbook;

    notebook_data_t *d = w->data;
    widget_t *child = g_hash_table_lookup(d->children, widget);

    lua_State *L = luakit.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -1, "attached", 0, 0);
    luaH_object_emit_signal(L, -2, "page-added", 1, 0);
    lua_pop(L, -1);
}

void
page_removed_cb(GtkNotebook *nbook, GtkWidget *widget, guint i, widget_t *w)
{
    (void) i;
    (void) nbook;

    notebook_data_t *d = w->data;
    widget_t *child = g_hash_table_lookup(d->children, widget);
    g_hash_table_remove(d->children, widget);
    child->parent = NULL;

    lua_State *L = luakit.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -1, "detached", 0, 0);
    luaH_object_emit_signal(L, -2, "page-removed", 1, 0);
    lua_pop(L, -1);
}

static void
notebook_destructor(widget_t *w)
{
    debug("destroying notebook");
    notebook_data_t *d = w->data;

    /* destroy gtk widgets */
    gtk_widget_destroy(d->nbook);

    /* destroy lookup table */
    g_hash_table_destroy(d->children);
}

widget_t *
widget_notebook(widget_t *w)
{
    w->index = luaH_notebook_index;
    w->newindex = luaH_notebook_newindex;
    w->destructor = notebook_destructor;

    notebook_data_t *d = w->data = g_new0(notebook_data_t, 1);

    /* Create notebook and set as main gtk widget */
    w->widget = d->nbook = gtk_notebook_new();
    gtk_notebook_set_show_border(GTK_NOTEBOOK(d->nbook), FALSE);
    gtk_notebook_set_scrollable(GTK_NOTEBOOK(d->nbook), TRUE);

    g_signal_connect(GTK_OBJECT(d->nbook), "page-added", G_CALLBACK(page_added_cb), w);
    g_signal_connect(GTK_OBJECT(d->nbook), "page-removed", G_CALLBACK(page_removed_cb), w);

    gtk_widget_show(d->nbook);

    /* Create reverse lookup table for child widgets */
    d->children = g_hash_table_new(g_direct_hash, g_direct_equal);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
