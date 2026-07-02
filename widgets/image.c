/*
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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

#include <webkit/webkit.h>

#include "gdk/gdk.h"
#include "gtk/gtk.h"
#include "luah.h"
#include "widgets/common.h"
#include "web_context.h"
#include "common/resource.h"

static widget_t*
luaH_checkimage(lua_State *L, gint udx)
{
    widget_t *w = luaH_checkwidget(L, udx);
    if (w->info->tok != L_TK_IMAGE)
        luaL_argerror(L, udx, "incorrect widget type (expected image)");
    return w;
}

static gint
luaH_image_set_from_file_name(lua_State *L)
{
    widget_t *w = luaH_checkimage(L, 1);
    gchar *path = (gchar*)luaL_checkstring(L, 2), *x2_path = NULL;

    float scale = gtk_widget_get_scale_factor(w->widget);

    path = resource_find_file(path);

    if (!path)
        return luaL_error(L, "unable to find image file");

    /* Detect @2x file if on HiDPI screen */
    if (scale == 2) {
        const gchar *ext = strrchr(path, '.') ?: &path[strlen(path)];
        x2_path = g_strdup_printf("%.*s@2x%s", (int)(ext - path), path, ext);
        if (!g_file_test(x2_path, G_FILE_TEST_IS_REGULAR)) {
            g_free(x2_path);
            x2_path = NULL;
        }
    }

    /* 2. Instantiate a modern GTK 4 texture from the scaled pixbuf */
    GError *error = NULL;
    GdkTexture *texture = gdk_texture_new_from_filename(x2_path ?: path, &error);
    if (error) {
        lua_pushstring(L, error->message);
        g_error_free(error);
        g_free(path);
        g_free(x2_path);
        return luaL_error(L, "unable to load image file: %s", lua_tostring(L, -1));
    }

    gtk_image_set_from_paintable(GTK_IMAGE(w->widget), GDK_PAINTABLE(texture));

    g_free(path);
    g_free(x2_path);
    return 0;
}

static gint
luaH_image_set_from_icon_name(lua_State *L)
{
    widget_t *w = luaH_checkimage(L, 1);

    gint size = luaL_checkint(L, 3);
    switch (size) {
        case 16:
        case 24:
        case 32:
        case 48:
            break;
        default:
            return luaL_error(L, "Bad icon size: must be 16, 24, 32, or 48.");
    }

    if (w->data) {
        g_cancellable_cancel(w->data);
        g_clear_object(&w->data);
    }

    gtk_image_set_from_icon_name(GTK_IMAGE(w->widget), luaL_checkstring(L, 2));
    gtk_image_set_pixel_size(GTK_IMAGE(w->widget), size);

    return 0;
}

static gint
luaH_image_scale(lua_State *L)
{
    widget_t *w = luaH_checkimage(L, 1);
    int width = luaL_checkinteger(L, 2);
    int height = lua_isnil(L, 3) ? width : luaL_checkinteger(L, 3);
    if (width <= 0 || height <= 0)
        return luaL_error(L, "Image dimensions must be positive");

    GdkPaintable *paintable = gtk_image_get_paintable(GTK_IMAGE(w->widget));
    gtk_image_set_from_paintable(GTK_IMAGE(w->widget), paintable);
    gtk_widget_set_size_request(GTK_WIDGET(w->widget), width, height);
    g_object_unref(paintable);

    return 0;
}

void
luaH_image_set_favicon_for_uri_finished(WebKitFaviconDatabase *fdb, GAsyncResult *res, widget_t *w)
{
    GdkTexture *texture = webkit_favicon_database_get_favicon_finish(fdb, res, NULL);
    if (!texture)
        return;

    float scale = gtk_widget_get_scale_factor(w->widget);
    float log_sz = 16, dev_sz = log_sz*scale;

    gtk_image_set_from_paintable(GTK_IMAGE(w->widget), GDK_PAINTABLE(texture));
    gtk_widget_set_size_request(GTK_WIDGET(w->widget), dev_sz, dev_sz);
    g_object_unref(texture);
}

static gint
luaH_image_set_favicon_for_uri(lua_State *L)
{
    widget_t *w = luaH_checkimage(L, 1);
    const gchar *uri = luaL_checkstring(L, 2);

    WebKitNetworkSession *net_session = web_network_session_get();
    WebKitWebsiteDataManager *data_manager = webkit_network_session_get_website_data_manager(net_session);
    WebKitFaviconDatabase *main_fdb = webkit_website_data_manager_get_favicon_database(data_manager);
    gchar *f_uri;
    gboolean ok = TRUE;

    if ((f_uri = webkit_favicon_database_get_favicon_uri(main_fdb, uri))) {
        g_free(f_uri);

        if (w->data) {
            g_cancellable_cancel(w->data);
            g_clear_object(&w->data);
        }
        w->data = g_cancellable_new();

        webkit_favicon_database_get_favicon(main_fdb, uri, w->data,
                (GAsyncReadyCallback)luaH_image_set_favicon_for_uri_finished, w);
    } else
        ok = FALSE;

    lua_pushboolean(L, ok);
    return 1;
}

static gint
luaH_image_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)

      PF_CASE(DESTROY,              luaH_widget_destroy)

      PF_CASE(FILENAME, luaH_image_set_from_file_name)
      PF_CASE(ICON, luaH_image_set_from_icon_name)
      PF_CASE(SCALE, luaH_image_scale)
      PF_CASE(SET_FAVICON_FOR_URI, luaH_image_set_favicon_for_uri)

      default:
        break;
    }
    return 0;
}

static gint
luaH_image_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

      default:
          return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_image(lua_State *UNUSED(L), widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_image_index;
    w->newindex = luaH_image_newindex;

    w->widget = gtk_image_new();
    w->data = NULL;

    g_object_connect(G_OBJECT(w->widget),
        LUAKIT_WIDGET_SIGNAL_COMMON(w)
        NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
