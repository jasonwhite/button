/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Path manipulation module.
 */
#include "path.h"

#include "lua.hpp"

static inline bool _issep(char c) {
#if PATH_STYLE == PATH_STYLE_WIN
    return c == '/' || c == '\\';
#else
    return c == '/';
#endif
}

static bool path_isabs(const char* path, size_t len) {
    if(len > 0 && _issep(path[0]))
        return true;

#if PATH_STYLE == PATH_STYLE_WIN
    if(len > 2 && path[1] == ':' && _issep(path[2]))
        return true;
#endif

    return false;
}

/**
 * Helper function to get the distance forward to a '/', '\', or to the end of
 * the buffer.
 */
/*static size_t _path_getelem(const char* path, size_t len)
{
    size_t i;

    for (i = 0; i < len; ++i) {
        if (_issep(path[i]))
            break;
    }

    return i;
}*/

int path_isabs(lua_State* L) {
    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);
    lua_pushboolean(L, path_isabs(path, len));
    return 1;
}

int path_join(lua_State* L) {

    int argc = lua_gettop(L);

    luaL_Buffer b;
    luaL_buffinit(L, &b);

    for (int i = 1; i <= argc; ++i) {
        size_t len;
        const char* path = luaL_checklstring(L, i, &len);

        if (path_isabs(path, len)) {
            // Path is absolute, reset the buffer length
            b.n = 0;
        }
        else {
            // Path is relative, add path separator if necessary.
            if (b.n > 0 && !_issep(b.b[b.n-1]))
                luaL_addchar(&b, PATH_SEP);
        }

        luaL_addlstring(&b, path, len);
    }

    luaL_pushresult(&b);
    return 1;
}

int path_split(lua_State* L) {

    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    // Search backwards for the last path separator
    size_t tail_start = len;

    while (tail_start > 0) {
        --tail_start;
        if (_issep(path[tail_start])) {
            ++tail_start;
            break;
        }
    }

    // Trim off the path separators
    size_t head_end = tail_start;
    while (head_end > 0) {
        --head_end;

        if (!_issep(path[head_end])) {
            ++head_end;
            break;
        }
    }

    if (head_end == 0)
        head_end = tail_start;

    lua_pushlstring(L, path, head_end); // head
    lua_pushlstring(L, path+tail_start, len-tail_start); // tail

    return 2;
}

int path_basename(lua_State* L) {
    path_split(L);
    lua_remove(L, -2); // Pop off the head
    return 1;
}

int path_dirname(lua_State* L) {
    path_split(L);
    lua_pop(L, 1); // Pop off the tail
    return 1;
}

int path_splitext(lua_State* L) {

    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    size_t base = len;

    // Find the base name
    while (base > 0) {
        --base;
        if (_issep(path[base])) {
            ++base;
            break;
        }
    }

    // Skip past initial dots
    while (base < len && path[base] == '.')
        ++base;

    // Skip past non-dots
    while (base < len && path[base] != '.')
        ++base;

    lua_pushlstring(L, path, base); // root
    lua_pushlstring(L, path+base, len-base); // extension
    return 2;
}

int path_getext(lua_State* L) {
    path_splitext(L);
    lua_remove(L, -2); // Pop off the root
    return 1;
}

int path_norm(lua_State* L) {

    //size_t len;
    //const char* path = luaL_checklstring(L, 1, &len);

    luaL_Buffer b;
    luaL_buffinit(L, &b);

    luaL_pushresult(&b);
    return 1;
}

static const luaL_Reg pathlib[] = {
    {"isabs", path_isabs},
    {"join", path_join},
    {"split", path_split},
    {"basename", path_basename},
    {"dirname", path_dirname},
    {"splitext", path_splitext},
    {"getext", path_getext},
    {"norm", path_norm},
    {NULL, NULL}
};

int luaopen_path(lua_State* L) {
    luaL_newlib(L, pathlib);
    return 1;
}
