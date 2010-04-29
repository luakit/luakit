#ifndef LUAKIT_UTIL_H
#define LUAKIT_UTIL_H

/* Replace NULL strings with "" */
#define NONULL(x) (x ? x : "")

#define fatal(string, ...) _fatal(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _fatal(int, const char *, const char *, ...);

#define warn(string, ...) _warn(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _warn(int, const char *, const char *, ...);

#ifdef DEBUG_MESSAGES

#define debug(string, ...) _debug(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _debug(int, const char *, const char *, ...);

#else

#define debug(string)

#endif

/* A NULL resistant strlen. Unlike it's libc sibling, l_strlen returns a
 * ssize_t, and supports its argument being NULL.
 *
 * param s the string.
 * return the string length (or 0 if s is NULL).
 */
static inline ssize_t l_strlen(const char *s)
{
    return s ? strlen(s) : 0;
}

#endif
