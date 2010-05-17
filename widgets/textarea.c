/*
 * textarea.c - gtk text area widget
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

#include "luakit.h"
#include "luah.h"
#include "widget.h"

typedef struct
{
    /* gtk label widget */
    GtkWidget *label;
    /* gtk event box widget */
    GtkWidget *ebox;
    /* label text */
    gchar *text;

} textarea_data_t;

static gint
luaH_textarea_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    (void) w;
    textarea_data_t *d = w->data;

    switch(token)
    {
      case L_TK_TEXT:
        lua_pushstring(L, d->text ? d->text : "");
        return 1;

      default:
        break;
    }
    return 0;
}

static gint
luaH_textarea_newindex(lua_State *L, luakit_token_t token)
{
    size_t len = 0;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    textarea_data_t *d = w->data;
    const gchar *tmp = NULL;
    (void) d;
    (void) len;

    switch(token)
    {
      case L_TK_TEXT:
        tmp = luaL_checklstring(L, 3, &len);
        if (d->text)
            g_free(d->text);
        d->text = g_strdup(tmp);
        gtk_label_set_markup(GTK_LABEL(d->label), d->text);
        luaH_object_emit_signal(L, 1, "property::text", 0);
        break;

      default:
        warn("trying to set unknown attribute on textarea widget");
        break;
    }
    return 0;
}

static void
textarea_destructor(widget_t *w)
{
    debug("destroying textarea");
    textarea_data_t *d = w->data;

    /* destroy gtk widgets */
    gtk_widget_destroy(d->ebox);
    gtk_widget_destroy(d->label);

    g_free(d->text);
}

widget_t *
widget_textarea(widget_t *w)
{
    w->index = luaH_textarea_index;
    w->newindex = luaH_textarea_newindex;
    w->destructor = textarea_destructor;

    textarea_data_t *d = w->data = g_new0(textarea_data_t, 1);

    d->text = NULL;

    /* Create eventbox and set as main gtk widget */
    w->widget = d->ebox = gtk_event_box_new();

    d->label = gtk_label_new(NULL);
    gtk_container_add(GTK_CONTAINER(d->ebox), d->label);

    /* setup default settings */
    gtk_label_set_selectable(GTK_LABEL(d->label), TRUE);
    gtk_label_set_ellipsize(GTK_LABEL(d->label), PANGO_ELLIPSIZE_END);
    gtk_label_set_use_markup(GTK_LABEL(d->label), TRUE);
    gtk_misc_set_alignment(GTK_MISC(d->label), 0, 0);
    gtk_misc_set_padding(GTK_MISC(d->label), 2, 2);


    gtk_widget_show(d->ebox);
    gtk_widget_show(d->label);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
