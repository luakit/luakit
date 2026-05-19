/*
 * web_context.c - WebKit web context setup and handling
 *
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

#include "globalconf.h"
#include "common/log.h"
#include "web_context.h"

#include <glib.h>
#include <webkit/webkit.h>

/** WebKit context common to all web views */
static WebKitWebContext *web_context;
static WebKitNetworkSession *net_session;

/** Defined in widgets/webview/downloads.c */
gboolean download_start_cb(WebKitWebContext *, WebKitDownload *, gpointer);

WebKitWebContext *
web_context_get(void)
{
    g_assert(web_context);
    return web_context;
}

WebKitNetworkSession *
web_network_session_get(void)
{
    g_assert(net_session);
    return net_session;
}

static void
website_data_manager_init(void)
{
    web_context = webkit_web_context_new ();

    net_session = webkit_network_session_new(
        globalconf.data_dir,
        globalconf.cache_dir);

    WebKitWebsiteDataManager *data_mgr = webkit_network_session_get_website_data_manager(net_session);

    webkit_website_data_manager_set_favicons_enabled(data_mgr, TRUE);

    /* Set default cookie policy: must match default in clib/soup.c */
    WebKitCookieManager *cookie_mgr = webkit_network_session_get_cookie_manager(net_session);
    webkit_cookie_manager_set_accept_policy(cookie_mgr, WEBKIT_COOKIE_POLICY_ACCEPT_NO_THIRD_PARTY);


    verbose("base_data_directory:                 %s", webkit_website_data_manager_get_base_data_directory(data_mgr));
    verbose("base_cache_directory:                %s", webkit_website_data_manager_get_base_cache_directory(data_mgr));
}

static void
web_context_set_default_spelling_language(void)
{
    /* This seems to autodetect spell checking languages */
    const gchar *null = NULL;
    webkit_web_context_set_spell_checking_languages(web_context, &null);
    gchar **ret = (gchar**)webkit_web_context_get_spell_checking_languages(web_context);
    if (!ret)
        return;
    gchar *langs = g_strjoinv(", ", ret);
    verbose("setting spell check languages: %s", langs);
    g_free(langs);
}

void
web_context_init(void)
{
    website_data_manager_init();
    g_signal_connect(G_OBJECT(web_context), "download-started",
            G_CALLBACK(download_start_cb), NULL);

    web_context_set_default_spelling_language();
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
