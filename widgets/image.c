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

#include <webkit2/webkit2.h>

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

    /* Load image into pixbuf */
    GError *error;
fallback:
    error = NULL;
    GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file(x2_path ?: path, &error);
    if (error)
        verbose("unable to load image file: %s", error->message);
    if (error && x2_path) {
        g_error_free(error);
        g_free(x2_path);
        x2_path = NULL;
        goto fallback;
    }
    if (error) {
        lua_pushstring(L, error->message);
        g_error_free(error);
        g_free(path);
        return luaL_error(L, "unable to load image file: %s", lua_tostring(L, -1));
    }

    if (w->data) {
        g_cancellable_cancel(w->data);
        g_clear_object(&w->data);
    }

    /* Convert to cairo surface, and scale */
    cairo_surface_t *source = gdk_cairo_surface_create_from_pixbuf(pixbuf, 1, 0);
    g_object_unref(G_OBJECT(pixbuf));

    float src_w = cairo_image_surface_get_width(source);
    float src_h = cairo_image_surface_get_height(source);

    cairo_surface_t *target = cairo_surface_create_similar(source,
            CAIRO_CONTENT_COLOR_ALPHA, src_w, src_h);
    cairo_surface_set_device_scale(target, scale, scale);

    cairo_t *cr = cairo_create(target);
    cairo_scale(cr, 1/scale, 1/scale);
    cairo_set_source_surface(cr, source, 0, 0);
    cairo_surface_set_device_offset(source, 0, 0);
    cairo_paint(cr);

    gtk_image_set_from_surface(GTK_IMAGE(w->widget), target);
    cairo_surface_destroy(source);
    cairo_surface_destroy(target);
    cairo_destroy(cr);

    g_free(path);
    g_free(x2_path);
    return 0;
}

static gint
luaH_image_set_from_icon_name(lua_State *L)
{
    widget_t *w = luaH_checkimage(L, 1);

    GtkIconSize size;
    switch (luaL_checkint(L, 3)) {
        case 16: size = GTK_ICON_SIZE_SMALL_TOOLBAR; break;
        case 24: size = GTK_ICON_SIZE_LARGE_TOOLBAR; break;
        case 32: size = GTK_ICON_SIZE_DND; break;
        case 48: size = GTK_ICON_SIZE_DIALOG; break;
        default:
            return luaL_error(L, "Bad icon size: must be 16, 24, 32, or 48.");
    }

    if (w->data) {
        g_cancellable_cancel(w->data);
        g_clear_object(&w->data);
    }

    gtk_image_set_from_icon_name(GTK_IMAGE(w->widget), luaL_checkstring(L, 2), size);

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

    GdkPixbuf *pixbuf = gtk_image_get_pixbuf(GTK_IMAGE(w->widget));
    GdkPixbuf *scaled_pixbuf = gdk_pixbuf_scale_simple(pixbuf, width, height, GDK_INTERP_BILINEAR);
    g_object_unref(pixbuf);
    gtk_image_set_from_pixbuf(GTK_IMAGE(w->widget), scaled_pixbuf);
    g_object_unref(scaled_pixbuf);

    return 0;
}

void
luaH_image_set_favicon_for_uri_finished(WebKitFaviconDatabase *fdb, GAsyncResult *res, widget_t *w)
{
    cairo_surface_t *source = webkit_favicon_database_get_favicon_finish(fdb, res, NULL);
    if (!source)
        return;

    /* Source width/height, scale factor, target logical size, target device size */
    float src_w = cairo_image_surface_get_width(source);
    float src_h = cairo_image_surface_get_height(source);
    float scale = gtk_widget_get_scale_factor(w->widget);
    float log_sz = 16, dev_sz = log_sz*scale;

    cairo_surface_t *target = cairo_surface_create_similar(source,
            CAIRO_CONTENT_COLOR_ALPHA, dev_sz, dev_sz);
    cairo_surface_set_device_scale(target, scale, scale);

    cairo_t *cr = cairo_create(target);
    cairo_scale(cr, log_sz/src_w, log_sz/src_h);
    cairo_set_source_surface(cr, source, 0, 0);
    cairo_surface_set_device_offset(source, 0, 0);
    cairo_paint(cr);

    gtk_image_set_from_surface(GTK_IMAGE(w->widget), target);
    cairo_surface_destroy(source);
    cairo_surface_destroy(target);
    cairo_destroy(cr);
}

static gint
luaH_image_set_favicon_for_uri(lua_State *L)
{
    widget_t *w = luaH_checkimage(L, 1);
    const gchar *uri = luaL_checkstring(L, 2);

    WebKitWebContext *main_ctx = web_context_get();
    WebKitFaviconDatabase *main_fdb = webkit_web_context_get_favicon_database(main_ctx);
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
        break;
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
