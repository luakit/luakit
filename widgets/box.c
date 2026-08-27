/*
 * widgets/box.c - gtk hbox & vbox container widgets
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

#include "glib-object.h"
#include "luah.h"
#include "widgets/common.h"

static gint
luaH_box_pack(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);

    gint top = lua_gettop(L);
    gboolean expand = FALSE, fill = FALSE, start = TRUE;
    guint padding = 0;

    /* check for options table */
    if (top > 2 && !lua_isnil(L, 3)) {
        luaH_checktable(L, 3);

        /* pack child from start or end of container? */
        if (luaH_rawfield(L, 3, "from"))
            start = L_TK_END == l_tokenize(lua_tostring(L, -1)) ? FALSE : TRUE;

        /* expand? */
        if (luaH_rawfield(L, 3, "expand"))
            expand = lua_toboolean(L, -1) ? TRUE : FALSE;

        /* fill? */
        if (luaH_rawfield(L, 3, "fill"))
            fill = lua_toboolean(L, -1) ? TRUE : FALSE;

        /* padding? */
        if (luaH_rawfield(L, 3, "padding"))
            padding = (guint)lua_tonumber(L, -1);

        /* return stack to original state */
        lua_settop(L, top);
    }
    GtkWidget* child_widget = GTK_WIDGET(child->widget);
    GtkOrientation orientation = gtk_orientable_get_orientation(GTK_ORIENTABLE(w->widget));

    if (orientation == GTK_ORIENTATION_HORIZONTAL) {
        gtk_widget_set_hexpand(child_widget, expand);
        gtk_widget_set_halign(child_widget, fill ? GTK_ALIGN_FILL : GTK_ALIGN_CENTER);
        if (expand || fill)
            gtk_widget_set_vexpand(child_widget, TRUE);
        gtk_widget_set_valign(child_widget, GTK_ALIGN_FILL);
        gtk_widget_set_margin_start(child_widget, padding);
        gtk_widget_set_margin_end(child_widget, padding);
    } else {
        gtk_widget_set_vexpand(child_widget, expand);
        gtk_widget_set_valign(child_widget, fill ? GTK_ALIGN_FILL : GTK_ALIGN_CENTER);
        if (expand || fill)
            gtk_widget_set_hexpand(child_widget, TRUE);
        gtk_widget_set_halign(child_widget, GTK_ALIGN_FILL);
        gtk_widget_set_margin_top(child_widget, padding);
        gtk_widget_set_margin_bottom(child_widget, padding);
    }

    if (start)
        gtk_box_append(GTK_BOX(w->widget), child_widget);
    else
        gtk_box_prepend(GTK_BOX(w->widget), child_widget);
    return 0;
}

/* direct wrapper around gtk_box_reorder_child */
static gint
luaH_box_reorder_child(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gint pos = luaL_checknumber(L, 3);

    if (pos == 0) {
        gtk_box_reorder_child_after(GTK_BOX(w->widget), GTK_WIDGET(child->widget), NULL);
    } else if (pos > 0) {
        gint current_index = 0;
        GtkWidget *child_widget = gtk_widget_get_first_child(GTK_WIDGET(w->widget));

        while (child_widget != NULL) {
            if (current_index == pos) {
                gtk_box_reorder_child_after(GTK_BOX(w->widget), GTK_WIDGET(child->widget), child_widget);
            }

            current_index++;
            child_widget = gtk_widget_get_next_sibling(child_widget);
        }
    }
    return 0;
}

static gint
luaH_box_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_CHILD_INDEX_COMMON(w)

      PF_CASE(DESTROY,      luaH_widget_destroy)

      /* push class methods */
      PF_CASE(PACK,         luaH_box_pack)
      PF_CASE(REORDER,      luaH_box_reorder_child)
      /* push boolean properties */
      PB_CASE(HOMOGENEOUS,  gtk_box_get_homogeneous(GTK_BOX(w->widget)))
      /* push string properties */
      PN_CASE(SPACING,      gtk_box_get_spacing(GTK_BOX(w->widget)))

      PS_CASE(BG, g_object_get_data(G_OBJECT(w->widget), "bg"))

      default:
        break;
    }
    return 0;
}

static gint
luaH_box_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    size_t len;
    const gchar *tmp;
    GdkRGBA c;

    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)
      LUAKIT_WIDGET_CHILD_NEWINDEX_COMMON(w)

      case L_TK_HOMOGENEOUS:
        gtk_box_set_homogeneous(GTK_BOX(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_SPACING:
        gtk_box_set_spacing(GTK_BOX(w->widget), luaL_checknumber(L, 3));
        break;

      case L_TK_BG:
        tmp = luaL_checklstring(L, 3, &len);
        if (!gdk_rgba_parse(&c, tmp))
            luaL_argerror(L, 3, "unable to parse colour");
        widget_set_css_properties(w, "background-color", tmp, NULL);
        g_object_set_data_full(G_OBJECT(w->widget), "bg", g_strdup(tmp), g_free);
        break;

      default:
        return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_box(lua_State *UNUSED(L), widget_t *w, luakit_token_t token)
{
    w->index = luaH_box_index;
    w->newindex = luaH_box_newindex;

    w->widget = gtk_box_new((token == L_TK_VBOX) ?
            GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL, 0);

    gtk_widget_set_hexpand(w->widget, TRUE);
    gtk_widget_set_vexpand(w->widget, TRUE);
    gtk_widget_set_halign(w->widget, GTK_ALIGN_FILL);
    gtk_widget_set_valign(w->widget, GTK_ALIGN_FILL);

    gtk_box_set_homogeneous(GTK_BOX(w->widget), (token == L_TK_VBOX) ? FALSE : TRUE);

    g_object_connect(G_OBJECT(w->widget),
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      NULL);

    GListModel *children = gtk_widget_observe_children(GTK_WIDGET(w->widget));
    g_object_connect(G_OBJECT(children),
      "signal::items-changed", G_CALLBACK(items_changed_cb), w,
      NULL);
    g_object_unref (children);

    LUAKIT_EVENT_CONTROLLER_MOTION(w->widget, w);

    LUAKIT_EVENT_CONTROLLER_GESTURE(w->widget, w)

    LUAKIT_EVENT_CONTROLLER_SCROLL(w->widget, w)

    gtk_widget_set_visible(w->widget, TRUE);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
