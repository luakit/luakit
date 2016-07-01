#include "luah.h"
#include "widgets/common.h"

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
    gtk_image_set_from_file(GTK_IMAGE(w->widget), luaL_checkstring(L, 2));
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
    pixbuf = scaled_pixbuf;

    return 0;
}

static gint
luaH_image_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)

      PF_CASE(FILENAME, luaH_image_set_from_file_name)
      PF_CASE(ICON, luaH_image_set_from_icon_name)
      PF_CASE(SCALE, luaH_image_scale)

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
widget_image(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_image_index;
    w->newindex = luaH_image_newindex;
    w->destructor = widget_destructor;

    w->widget = gtk_image_new();

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
