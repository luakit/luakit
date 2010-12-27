/*
 * soup_auth.c - authentication management
 *
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

static struct {
    SoupSession *session;
    SoupMessage *msg;
    SoupAuth *auth;
} CurrentAuth = { NULL, NULL, NULL };

static void
soup_auth_feature_interface_init(SoupSessionFeatureInterface *, gpointer);

G_DEFINE_TYPE_WITH_CODE(SoupAuthFeature, soup_auth_feature, G_TYPE_OBJECT,
        G_IMPLEMENT_INTERFACE(SOUP_TYPE_SESSION_FEATURE, soup_auth_feature_interface_init))

static void
session_authenticate(SoupSession *session, SoupMessage *msg,
        SoupAuth *auth, gboolean retrying, gpointer user_data)
{
    (void) retrying;
    (void) user_data;

    lua_State *L = globalconf.L;

    /*
     * Workaround for http://bugzilla.gnome.org/show_bug.cgi?id=583462
     * FIXME: we can remove this once we depend on a libsoup newer than 2.26.2
     */
    if (msg->status_code == 0)
        return;

    SoupURI *soup_uri = soup_message_get_uri(msg);
    const char *uri = soup_uri_to_string(soup_uri, FALSE);

    soup_session_pause_message(session, msg);
    // We need to make sure the message sticks around when pausing it
    g_object_ref(msg);

    lua_pushstring(L, uri);
    signal_object_emit(L, globalconf.signals, "authenticate", 1);

    CurrentAuth.session = session;
    CurrentAuth.msg = msg;
    CurrentAuth.auth = auth;
}

void
soup_auth_feature_resume_authentication(const char *username, const char *password)
{
    soup_auth_authenticate(CurrentAuth.auth, username, password);
    soup_session_unpause_message(CurrentAuth.session, CurrentAuth.msg);
    g_object_unref(CurrentAuth.msg);
}

static void
attach(SoupSessionFeature *manager, SoupSession *session)
{
    g_signal_connect(session, "authenticate", G_CALLBACK(session_authenticate), manager);
}

static void
detach(SoupSessionFeature *manager, SoupSession *session)
{
    g_signal_handlers_disconnect_by_func(session, session_authenticate, manager);
}

static void
soup_auth_feature_interface_init(SoupSessionFeatureInterface *feature_interface,
        gpointer interface_data)
{
    (void) interface_data;

    feature_interface->attach = attach;
    feature_interface->detach = detach;
}

static void
soup_auth_feature_class_init(SoupAuthFeatureClass *klass)
{
    (void) klass;
}

static void
soup_auth_feature_init(SoupAuthFeature *instance)
{
    (void) instance;
}

SoupAuthFeature *
soup_auth_feature_new()
{
    SoupAuthFeature *feature = g_object_new(TYPE_SOUP_AUTH_FEATURE, NULL);
    return feature;
}

