/*
 * web_context.c - WebKit web context setup and handling
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
#include "web_context.h"

#include <webkit2/webkit2.h>

/** WebKit context common to all web views */
static WebKitWebContext *web_context;

/** Defined in widgets/webview.c */
void luakit_uri_scheme_request_cb(WebKitURISchemeRequest *, gpointer);
/** Defined in widgets/webview/downloads.c */
gboolean download_start_cb(WebKitWebContext *, WebKitDownload *, gpointer);

WebKitWebContext *
web_context_get(void)
{
    g_assert(web_context);
    return web_context;
}

static void
website_data_dir_init(void)
{
    g_assert(globalconf.data_dir);

    gchar *indexeddb_dir = g_build_filename(globalconf.data_dir, "indexeddb", NULL);
    gchar *local_storage_dir = g_build_filename(globalconf.data_dir, "local_storage", NULL);
    gchar *applications_dir = g_build_filename(globalconf.data_dir, "applications", NULL);
    gchar *websql_dir = g_build_filename(globalconf.data_dir, "websql", NULL);

    WebKitWebsiteDataManager *data_mgr = webkit_website_data_manager_new(
            "disk-cache-directory", globalconf.cache_dir,
            "indexeddb-directory", indexeddb_dir,
            "local-storage-directory", local_storage_dir,
            "offline-application-cache-directory", applications_dir,
            "websql-directory", websql_dir,
            NULL);

    g_free(indexeddb_dir);
    g_free(local_storage_dir);
    g_free(applications_dir);
    g_free(websql_dir);

    web_context = webkit_web_context_new_with_website_data_manager(data_mgr);

    verbose("base_data_directory:                 %s", webkit_website_data_manager_get_base_data_directory(data_mgr));
    verbose("base_cache_directory:                %s", webkit_website_data_manager_get_base_cache_directory(data_mgr));
    verbose("disk_cache_directory:                %s", webkit_website_data_manager_get_disk_cache_directory(data_mgr));
    verbose("indexeddb_directory:                 %s", webkit_website_data_manager_get_indexeddb_directory(data_mgr));
    verbose("local_storage_directory:             %s", webkit_website_data_manager_get_local_storage_directory(data_mgr));
    verbose("offline_application_cache_directory: %s", webkit_website_data_manager_get_offline_application_cache_directory(data_mgr));
    verbose("websql_directory:                    %s", webkit_website_data_manager_get_websql_directory(data_mgr));
}

void
web_context_init(void)
{
    website_data_dir_init();
    /* Misc settings */

    webkit_web_context_register_uri_scheme(web_context, "luakit",
            (WebKitURISchemeRequestCallback) luakit_uri_scheme_request_cb, NULL, NULL);
    webkit_web_context_set_favicon_database_directory(web_context, NULL);

    g_signal_connect(G_OBJECT(web_context), "download-started",
            G_CALLBACK(download_start_cb), NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
