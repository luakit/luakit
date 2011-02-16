/*
 * soup_auth.c - authentication management
 *
 * Copyright (C) 2009 Igalia S.L.
 * Copyright (C) 2010 Fabian Streitel <karottenreibe@gmail.com>
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

#include "classes/soup_auth.h"
#include "luah.h"

static void luakit_soup_auth_dialog_session_feature_init(SoupSessionFeatureInterface* feature_interface, gpointer interface_data);
static void attach(SoupSessionFeature* manager, SoupSession* session);
static void detach(SoupSessionFeature* manager, SoupSession* session);

G_DEFINE_TYPE_WITH_CODE(LuaKitSoupAuthDialog, luakit_soup_auth_dialog, G_TYPE_OBJECT,
                        G_IMPLEMENT_INTERFACE(SOUP_TYPE_SESSION_FEATURE,
                                              luakit_soup_auth_dialog_session_feature_init))

static void
luakit_soup_auth_dialog_class_init(LuaKitSoupAuthDialogClass* klass)
{
    (void) klass;
}

static void
luakit_soup_auth_dialog_init(LuaKitSoupAuthDialog* instance)
{
    (void) instance;
}

static void
luakit_soup_auth_dialog_session_feature_init(SoupSessionFeatureInterface *feature_interface, gpointer interface_data)
{
    (void) interface_data;

    feature_interface->attach = attach;
    feature_interface->detach = detach;
}

typedef struct {
    SoupMessage* msg;
    SoupAuth* auth;
    SoupSession* session;
    SoupSessionFeature* manager;
    GtkWidget* loginEntry;
    GtkWidget* passwordEntry;
    GtkWidget* checkButton;
} LuaKitAuthData;

static void
free_authData(LuaKitAuthData* authData)
{
    g_object_unref(authData->msg);
    g_slice_free(LuaKitAuthData, authData);
}

static void
luakit_store_password(SoupURI *soup_uri, const gchar *login, const gchar *password)
{
    lua_State *L = globalconf.L;
    gchar *uri = soup_uri_to_string(soup_uri, FALSE);
    lua_pushstring(L, uri);
    lua_pushstring(L, login);
    lua_pushstring(L, password);
    signal_object_emit(L, globalconf.signals, "store-password", 3, LUA_MULTRET);
    g_free(uri);
}

static void
luakit_find_password(SoupURI *soup_uri, const gchar **login, const gchar **password)
{
    lua_State *L = globalconf.L;
    gchar *uri = soup_uri_to_string(soup_uri, FALSE);
    lua_pushstring(L, uri);
    gint ret = signal_object_emit(L, globalconf.signals, "authenticate", 1, LUA_MULTRET);
    g_free(uri);
    if (ret >= 2) {
        *password = luaL_checkstring(L, -1);
        *login = luaL_checkstring(L, -2);
    }
    lua_pop(L, ret);
}

static void
response_callback(GtkDialog* dialog, gint response_id, LuaKitAuthData* authData)
{
    const gchar* login;
    const gchar* password;
    SoupURI* uri;
    gboolean storePassword;

    switch(response_id) {
      case GTK_RESPONSE_OK:
        login = gtk_entry_get_text(GTK_ENTRY(authData->loginEntry));
        password = gtk_entry_get_text(GTK_ENTRY(authData->passwordEntry));
        soup_auth_authenticate(authData->auth, login, password);

        storePassword = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(authData->checkButton));
        if (storePassword) {
            uri = soup_message_get_uri(authData->msg);
            luakit_store_password(uri, login, password);
        }
      default:
        break;
    }

    soup_session_unpause_message(authData->session, authData->msg);
    free_authData(authData);
    gtk_widget_destroy(GTK_WIDGET(dialog));
}

static GtkWidget *
table_add_entry(GtkWidget* table, gint row, const gchar* label_text, const gchar* value, gpointer user_data)
{
    (void) user_data;

    GtkWidget* label = gtk_label_new(label_text);
    gtk_misc_set_alignment(GTK_MISC(label), 0.0, 0.5);

    GtkWidget* entry = gtk_entry_new();
    gtk_entry_set_activates_default(GTK_ENTRY(entry), TRUE);

    if (value) {
        gtk_entry_set_text(GTK_ENTRY(entry), value);
    }

    gtk_table_attach(GTK_TABLE(table), label, 0, 1, row, row + 1, GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);
    gtk_table_attach_defaults(GTK_TABLE(table), entry, 1, 2, row, row + 1);

    return entry;
}

static void
show_auth_dialog(LuaKitAuthData* authData, const char* login, const char* password)
{
    GtkWidget* widget = gtk_dialog_new();
    GtkWindow* window = GTK_WINDOW(widget);
    GtkDialog* dialog = GTK_DIALOG(widget);

    gtk_dialog_add_buttons(dialog,
                           GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
                           GTK_STOCK_OK, GTK_RESPONSE_OK,
                           NULL);

    /* set dialog properties */
    gtk_dialog_set_has_separator(dialog, FALSE);
    gtk_container_set_border_width(GTK_CONTAINER(dialog), 5);
    gtk_box_set_spacing(GTK_BOX(dialog->vbox), 2);
    gtk_container_set_border_width(GTK_CONTAINER(dialog->action_area), 5);
    gtk_box_set_spacing(GTK_BOX(dialog->action_area), 6);
    gtk_window_set_resizable(window, FALSE);
    gtk_window_set_title(window, "");
    gtk_window_set_icon_name(window, GTK_STOCK_DIALOG_AUTHENTICATION);

    gtk_dialog_set_default_response(dialog, GTK_RESPONSE_OK);

    /* build contents */
    GtkWidget* hbox = gtk_hbox_new(FALSE, 12);
    gtk_container_set_border_width(GTK_CONTAINER(hbox), 5);
    gtk_box_pack_start(GTK_BOX(dialog->vbox), hbox, TRUE, TRUE, 0);

    GtkWidget* icon = gtk_image_new_from_stock(GTK_STOCK_DIALOG_AUTHENTICATION, GTK_ICON_SIZE_DIALOG);

    gtk_misc_set_alignment(GTK_MISC(icon), 0.5, 0.0);
    gtk_box_pack_start(GTK_BOX(hbox), icon, FALSE, FALSE, 0);

    GtkWidget* mainVBox = gtk_vbox_new(FALSE, 18);
    gtk_box_pack_start(GTK_BOX(hbox), mainVBox, TRUE, TRUE, 0);

    SoupURI* uri = soup_message_get_uri(authData->msg);
    gchar* message = g_strdup_printf("A username and password are being requested by the site %s", uri->host);
    GtkWidget* messageLabel = gtk_label_new(message);
    g_free(message);
    gtk_misc_set_alignment(GTK_MISC(messageLabel), 0.0, 0.5);
    gtk_label_set_line_wrap(GTK_LABEL(messageLabel), TRUE);
    gtk_box_pack_start(GTK_BOX(mainVBox), GTK_WIDGET(messageLabel), FALSE, FALSE, 0);

    GtkWidget* vbox = gtk_vbox_new(FALSE, 6);
    gtk_box_pack_start(GTK_BOX(mainVBox), vbox, FALSE, FALSE, 0);

    /* the table that holds the entries */
    GtkWidget* entryContainer = gtk_alignment_new(0.0, 0.0, 1.0, 1.0);

    gtk_alignment_set_padding(GTK_ALIGNMENT(entryContainer), 0, 0, 0, 0);

    gtk_box_pack_start(GTK_BOX(vbox), entryContainer, FALSE, FALSE, 0);

    GtkWidget* table = gtk_table_new(2, 2, FALSE);
    gtk_table_set_col_spacings(GTK_TABLE(table), 12);
    gtk_table_set_row_spacings(GTK_TABLE(table), 6);
    gtk_container_add(GTK_CONTAINER(entryContainer), table);

    authData->loginEntry = table_add_entry(table, 0, "Username:", login, NULL);
    authData->passwordEntry = table_add_entry(table, 1, "Password:", password, NULL);

    gtk_entry_set_visibility(GTK_ENTRY(authData->passwordEntry), FALSE);

    GtkWidget* rememberBox = gtk_vbox_new(FALSE, 6);
    gtk_box_pack_start(GTK_BOX(vbox), rememberBox,
                        FALSE, FALSE, 0);

    GtkWidget* checkButton = gtk_check_button_new_with_label("Store password");
    gtk_label_set_line_wrap(GTK_LABEL(gtk_bin_get_child(GTK_BIN(checkButton))), TRUE);
    gtk_box_pack_start(GTK_BOX(rememberBox), checkButton, FALSE, FALSE, 0);
    authData->checkButton = checkButton;

    g_signal_connect(dialog, "response", G_CALLBACK(response_callback), authData);
    gtk_widget_show_all(widget);
}

static void
session_authenticate(SoupSession* session, SoupMessage* msg, SoupAuth* auth, gboolean retrying, gpointer user_data)
{
    (void) retrying;

    SoupSessionFeature* manager = (SoupSessionFeature*)user_data;

    soup_session_pause_message(session, msg);
    /* We need to make sure the message sticks around when pausing it */
    g_object_ref(msg);

    SoupURI* uri = soup_message_get_uri(msg);
    LuaKitAuthData* authData = g_slice_new(LuaKitAuthData);
    authData->msg = msg;
    authData->auth = auth;
    authData->session = session;
    authData->manager = manager;

    const gchar *login = NULL;
    const gchar *password = NULL;
    luakit_find_password(uri, &login, &password);
    show_auth_dialog(authData, login, password);
    // TODO: g_free login and password?
}

static void
attach(SoupSessionFeature* manager, SoupSession* session)
{
    g_signal_connect(session, "authenticate", G_CALLBACK(session_authenticate), manager);
}

static void
detach(SoupSessionFeature* manager, SoupSession* session)
{
    g_signal_handlers_disconnect_by_func(session, session_authenticate, manager);
}

LuaKitSoupAuthDialog *
luakit_soup_auth_dialog_new()
{
    return g_object_new(LUAKIT_TYPE_SOUP_AUTH_DIALOG, NULL);
}

