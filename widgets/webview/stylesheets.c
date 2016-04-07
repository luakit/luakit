#if WITH_WEBKIT2

guint
stylesheet_add(const gchar *source)
{
    WebKitUserStyleSheet *stylesheet = webkit_user_style_sheet_new(source,
            WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES, WEBKIT_USER_STYLE_LEVEL_USER, NULL, NULL);
    g_ptr_array_add(globalconf.stylesheets, stylesheet);
    return globalconf.stylesheets->len - 1;
}

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
