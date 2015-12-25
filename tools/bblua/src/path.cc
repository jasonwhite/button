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

namespace path {

static bool isabs(const char* path, size_t len) {
    if(len > 0 && issep(path[0]))
        return true;

#if PATH_STYLE == PATH_STYLE_WIN
    if(len > 2 && path[1] == ':' && issep(path[2]))
        return true;
#endif

    return false;
}

/**
 * Helper function to get the distance forward to a '/', '\', or to the end of
 * the buffer.
 */
/*static size_t _getelem(const char* path, size_t len)
{
    size_t i;

    for (i = 0; i < len; ++i) {
        if (issep(path[i]))
            break;
    }

    return i;
}*/

int isabs(lua_State* L) {
    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);
    lua_pushboolean(L, isabs(path, len));
    return 1;
}

int join(lua_State* L) {

    int argc = lua_gettop(L);

    luaL_Buffer b;
    luaL_buffinit(L, &b);

    for (int i = 1; i <= argc; ++i) {
        size_t len;
        const char* path = luaL_checklstring(L, i, &len);

        if (isabs(path, len)) {
            // Path is absolute, reset the buffer length
            b.n = 0;
        }
        else {
            // Path is relative, add path separator if necessary.
            if (b.n > 0 && !issep(b.b[b.n-1]))
                luaL_addchar(&b, defaultSep);
        }

        luaL_addlstring(&b, path, len);
    }

    luaL_pushresult(&b);
    return 1;
}

int split(lua_State* L) {

    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    // Search backwards for the last path separator
    size_t tail_start = len;

    while (tail_start > 0) {
        --tail_start;
        if (issep(path[tail_start])) {
            ++tail_start;
            break;
        }
    }

    // Trim off the path separators
    size_t head_end = tail_start;
    while (head_end > 0) {
        --head_end;

        if (!issep(path[head_end])) {
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

int basename(lua_State* L) {
    split(L);
    lua_remove(L, -2); // Pop off the head
    return 1;
}

int dirname(lua_State* L) {
    split(L);
    lua_pop(L, 1); // Pop off the tail
    return 1;
}

int splitext(lua_State* L) {

    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    size_t base = len;

    // Find the base name
    while (base > 0) {
        --base;
        if (issep(path[base])) {
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

int getext(lua_State* L) {
    splitext(L);
    lua_remove(L, -2); // Pop off the root
    return 1;
}

int norm(lua_State* L) {

    //size_t len;
    //const char* path = luaL_checklstring(L, 1, &len);

    luaL_Buffer b;
    luaL_buffinit(L, &b);

    luaL_pushresult(&b);
    return 1;
}

static const luaL_Reg pathlib[] = {
    {"isabs", isabs},
    {"join", join},
    {"split", split},
    {"basename", basename},
    {"dirname", dirname},
    {"splitext", splitext},
    {"getext", getext},
    {"norm", norm},
    {NULL, NULL}
};

int luaopen(lua_State* L) {
    luaL_newlib(L, pathlib);
    return 1;
}

}
