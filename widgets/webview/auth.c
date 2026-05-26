/*
 * widgets/webview/auth.c - authentication management
 *
 * Copyright © 2009 Igalia S.L.
 * Copyright © 2010 Fabian Streitel <karottenreibe@gmail.com>
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
#include "web_context.h"

#include <gtk/gtk.h>

typedef struct {
    WebKitAuthenticationRequest *request;
    widget_t *w;
    GtkWidget *login_entry;
    GtkWidget *password_entry;
    GtkWidget *checkbutton;
} LuakitAuthData;

static void
free_auth_data(LuakitAuthData *auth_data)
{
    g_object_unref(auth_data->request);
    g_slice_free(LuakitAuthData, auth_data);
}

static void
luakit_store_password(LuakitAuthData *auth_data, const gchar *login, const gchar *password)
{
    lua_State *L = common.L;
    const gchar *uri = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(auth_data->w->widget));
    luaH_object_push(L, auth_data->w->ref);
    lua_pushstring(L, uri);
    lua_pushstring(L, login);
    lua_pushstring(L, password);
    luaH_object_emit_signal(L, -4, "store-password", 3, 0);
    lua_pop(L, 1);
}

static void
luakit_find_password(LuakitAuthData *auth_data, const gchar **login, const gchar **password)
{
    lua_State *L = common.L;
    const gchar *uri = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(auth_data->w->widget));
    luaH_object_push(L, auth_data->w->ref);
    lua_pushstring(L, uri);
    gint ret = luaH_object_emit_signal(L, -2, "store-password", 1, LUA_MULTRET);
    if (ret >= 2) {
        *password = luaL_checkstring(L, -1);
        *login = luaL_checkstring(L, -2);
    }
    lua_pop(L, 1 + ret);
}

static void
response_callback(GtkDialog *dialog, gint response_id, LuakitAuthData *auth_data)
{
    const gchar *login;
    const gchar *password;
    gboolean store_password;
    WebKitCredential *credential;

    switch(response_id)
    {
      case GTK_RESPONSE_OK:
        login = gtk_editable_get_text(GTK_EDITABLE(auth_data->login_entry));
        password = gtk_editable_get_text(GTK_EDITABLE(auth_data->password_entry));
        credential = webkit_credential_new(login, password, WEBKIT_CREDENTIAL_PERSISTENCE_NONE);
        webkit_authentication_request_authenticate(auth_data->request, credential);
        webkit_credential_free(credential);

        store_password = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(auth_data->checkbutton));
        if (store_password)
            luakit_store_password(auth_data, login, password);

      default:
        break;
    }

    free_auth_data(auth_data);
    gtk_window_destroy(GTK_WINDOW(dialog));
}

static GtkWidget *
table_add_entry(GtkWidget *table, gint row, const gchar *label_text,
        const gchar *value, gpointer UNUSED(user_data))
{
    GtkWidget *label = gtk_label_new(label_text);
    GValue align = G_VALUE_INIT;
    g_value_init(&align, G_TYPE_ENUM);
    g_value_set_int(&align, GTK_ALIGN_CENTER);
    g_object_set_property(G_OBJECT(label), "halign", &align);
    gtk_widget_set_vexpand(GTK_WIDGET(label), TRUE);

    GtkWidget *entry = gtk_entry_new();
    gtk_entry_set_activates_default(GTK_ENTRY(entry), TRUE);

    if (value)
        gtk_editable_set_text(GTK_EDITABLE(entry), value);

    // left,top,width,height
    gtk_grid_attach(GTK_GRID(table), label, 0, row, 1, 1);
    gtk_grid_attach(GTK_GRID(table), entry, 1, row, 1, 1);

    /* fill in all directions */
    gtk_widget_set_halign(label, GTK_ALIGN_FILL);
    gtk_widget_set_valign(label, GTK_ALIGN_FILL);
    gtk_widget_set_halign(entry, GTK_ALIGN_FILL);
    gtk_widget_set_valign(entry, GTK_ALIGN_FILL);
    /* expand vertically */
    gtk_widget_set_vexpand(label, TRUE);
    gtk_widget_set_vexpand(entry, TRUE);

    return entry;
}

static void
show_auth_dialog(LuakitAuthData *auth_data, const char *login, const char *password)
{
    GtkWidget *widget = gtk_dialog_new();
    GtkWindow *window = GTK_WINDOW(widget);
    GtkDialog *dialog = GTK_DIALOG(widget);

    gtk_dialog_add_buttons(dialog,
       "_Cancel", GTK_RESPONSE_CANCEL,
       "_OK", GTK_RESPONSE_OK,
       NULL);

    /* set dialog properties */
    GtkWidget *content_area = gtk_dialog_get_content_area(dialog);
    gtk_widget_set_margin_start(content_area, 5);
    gtk_widget_set_margin_end(content_area, 5);
    gtk_widget_set_margin_top(content_area, 5);
    gtk_widget_set_margin_bottom(content_area, 5);

    gtk_window_set_resizable(window, FALSE);
    gtk_window_set_title(window, "");
    gtk_window_set_icon_name(window, "dialog-password");

    gtk_dialog_set_default_response(dialog, GTK_RESPONSE_OK);

    /* build contents */
    GtkWidget *hbox = gtk_grid_new();
    gtk_widget_set_margin_start(hbox, 5);
    gtk_widget_set_margin_end(hbox, 5);
    gtk_widget_set_margin_top(hbox, 5);
    gtk_widget_set_margin_bottom(hbox, 5);

    gtk_grid_set_column_spacing(GTK_GRID(hbox), 12);
    gtk_box_append(GTK_BOX(content_area), hbox);
    gtk_widget_set_hexpand(hbox, TRUE);
    gtk_widget_set_vexpand(hbox, TRUE);

    GtkWidget *icon = gtk_image_new_from_icon_name("dialog-password");

    GValue align = G_VALUE_INIT;
    g_value_init(&align, G_TYPE_ENUM);
    g_value_set_int(&align, GTK_ALIGN_CENTER);
    g_object_set_property(G_OBJECT(hbox), "halign", &align);

    gtk_grid_attach(GTK_GRID(hbox), icon, 0,0,1,2);

    gtk_grid_set_row_spacing(GTK_GRID(hbox), 6);

    gchar *msg = g_strdup_printf("A username and password are being requested by the site %s",
            webkit_authentication_request_get_host(auth_data->request));
    GtkWidget *msg_label = gtk_label_new(msg);
    g_free(msg);
    g_object_set_property(G_OBJECT(msg_label), "halign", &align);
    gtk_label_set_wrap(GTK_LABEL(msg_label), TRUE);
    GValue max_width_chars = G_VALUE_INIT;
    g_value_init(&max_width_chars, G_TYPE_INT);
    g_value_set_int(&max_width_chars, 32);
    /* TODO this is a kludge */
    g_object_set_property(G_OBJECT(msg_label), "max-width-chars", &max_width_chars);
    gtk_grid_attach_next_to(GTK_GRID(hbox), GTK_WIDGET(msg_label), icon, GTK_POS_RIGHT, 1, 1);
    gtk_widget_set_hexpand(GTK_WIDGET(msg_label), FALSE);
    gtk_widget_set_vexpand(GTK_WIDGET(msg_label), TRUE);

    GtkWidget *table = gtk_grid_new();
    gtk_grid_attach_next_to(GTK_GRID(hbox), table, GTK_WIDGET(msg_label), GTK_POS_BOTTOM, 1, 1);

    gtk_grid_set_column_homogeneous(GTK_GRID(table), FALSE);
    gtk_grid_set_row_homogeneous(GTK_GRID(table), FALSE);
    gtk_grid_set_column_spacing(GTK_GRID(table), 12);
    gtk_grid_set_row_spacing(GTK_GRID(table), 6);

    auth_data->login_entry = table_add_entry(table, 0, "Username:", login, NULL);
    auth_data->password_entry = table_add_entry(table, 1, "Password:", password, NULL);

    gtk_entry_set_visibility(GTK_ENTRY(auth_data->password_entry), FALSE);

    GtkWidget *checkbutton = gtk_check_button_new_with_label("Store password");
    gtk_grid_attach_next_to(GTK_GRID(hbox), checkbutton, table, GTK_POS_BOTTOM, 1, 1);
    auth_data->checkbutton = checkbutton;

    g_signal_connect(dialog, "response", G_CALLBACK(response_callback), auth_data);
    gtk_window_present(window);
}

static gboolean
session_authenticate(WebKitWebView *UNUSED(web_view), WebKitAuthenticationRequest *request, widget_t *w)
{
    g_object_ref(request);

    LuakitAuthData *auth_data = g_slice_new(LuakitAuthData);
    auth_data->request = request;
    auth_data->w = w;

    const gchar *login = NULL;
    const gchar *password = NULL;
    luakit_find_password(auth_data, &login, &password);
    show_auth_dialog(auth_data, login, password);
    /* TODO: g_free login and password? */

    return TRUE;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
