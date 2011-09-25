/*
 * widgets/webview/frames.c - webkit webview frames functions
 *
 * Copyright © 2010-2011 Mason Larobina <mason.larobina@gmail.com>
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

GHashTable *frames_by_view = NULL;

typedef struct {
    WebKitWebView *view;
    WebKitWebFrame *frame;
} frame_destroy_callback_t;

static gint
luaH_webview_push_frames(lua_State *L, webview_data_t *d)
{
    GHashTable *frames = g_hash_table_lookup(frames_by_view, d->view);
    lua_createtable(L, g_hash_table_size(frames), 0);
    gint i = 1, tidx = lua_gettop(L);
    gpointer frame;
    GHashTableIter iter;
    g_hash_table_iter_init(&iter, frames);
    while (g_hash_table_iter_next(&iter, &frame, NULL)) {
        lua_pushlightuserdata(L, frame);
        lua_rawseti(L, tidx, i++);
    }
    return 1;
}

static void
frame_destroyed_cb(frame_destroy_callback_t *st)
{
    gpointer hash = g_hash_table_lookup(frames_by_view, st->view);
    /* the view might be destroyed before the frames */
    if (hash)
        g_hash_table_remove(hash, st->frame);
    g_slice_free(frame_destroy_callback_t, st);
}

static void
document_load_finished_cb(WebKitWebView *v, WebKitWebFrame *f,
        widget_t* UNUSED(w))
{
    /* add a bogus property to the frame so we get notified when it's destroyed */
    frame_destroy_callback_t *st = g_slice_new(frame_destroy_callback_t);
    st->view = v;
    st->frame = f;
    g_object_set_data_full(G_OBJECT(f), "dummy-destroy-notify", st,
            (GDestroyNotify)frame_destroyed_cb);
    GHashTable *frames = g_hash_table_lookup(frames_by_view, v);
    g_hash_table_insert(frames, f, NULL);
}
