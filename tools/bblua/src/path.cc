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

int cmp(char a, char b) {
    if (issep(a) && issep(b))
        return 0;

#if PATH_STYLE == PATH_STYLE_WINDOWS
    return (int)tolower(a) - (int)tolower(b);
#else
    return (int)a - (int)b;
#endif
}

int cmp(const char* a, const char* b, size_t len) {
	int result;
	for (size_t i = 0; i < len; ++i) {
        result = cmp(a[i], b[i]);
        if (result != 0)
            break;
	}

	return result;
}

int cmp(const char* a, const char* b, size_t len1, size_t len2) {
    if (len1 < len2)
        return -1;
    else if (len2 < len1)
        return 1;

    // Lengths are equal
    return cmp(a, b, len1);
}

bool Path::isabs() const {
    if(length > 0 && issep(path[0]))
        return true;

#if PATH_STYLE == PATH_STYLE_WINDOWS
    if(length > 2 && path[1] == ':' && issep(path[2]))
        return true;
#endif

    return false;
}

Path Path::dirname() const {
    return split(*this).head;
}

Path Path::basename() const {
    return split(*this).tail;
}

std::string Path::copy() const {
    return std::string(path, length);
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

Split split(Path path) {

    // Search backwards for the last path separator
    size_t tail_start = path.length;

    while (tail_start > 0) {
        --tail_start;
        if (issep(path.path[tail_start])) {
            ++tail_start;
            break;
        }
    }

    // Trim off the path separators
    size_t head_end = tail_start;
    while (head_end > 0) {
        --head_end;

        if (!issep(path.path[head_end])) {
            ++head_end;
            break;
        }
    }

    if (head_end == 0)
        head_end = tail_start;

    Split s;
    s.head.path   = path.path;
    s.head.length = head_end;
    s.tail.path   = path.path+tail_start;
    s.tail.length = path.length-tail_start;
    return s;
}

Split splitExtension(Path path) {
    size_t base = path.length;

    // Find the base name
    while (base > 0) {
        --base;
        if (issep(path.path[base])) {
            ++base;
            break;
        }
    }

    // Skip past initial dots
    while (base < path.length && path.path[base] == '.')
        ++base;

    // Skip past non-dots
    while (base < path.length && path.path[base] != '.')
        ++base;

    Split s;
    s.head.path = path.path;
    s.head.length = base;
    s.tail.path = path.path+base;
    s.tail.length = path.length-base;
    return s;
}

std::string& join(std::string& buf, Path path)
{
    if (path.isabs()) {
        // Path is absolute, reset the buffer length
        buf.clear();
    }
    else {
        // Path is relative, add path separator if necessary.
        size_t len = buf.size();
        if (len > 0 && !issep(buf[len-1]))
            buf.push_back(defaultSep);
    }

    return buf.append(path.path, path.length);
}

}

static int path_isabs(lua_State* L) {
    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);
    lua_pushboolean(L, path::Path(path, len).isabs());
    return 1;
}

static int path_join(lua_State* L) {

    int argc = lua_gettop(L);

    luaL_Buffer b;
    luaL_buffinit(L, &b);

    for (int i = 1; i <= argc; ++i) {
        if (lua_isnil(L, i))
            continue;

        size_t len;
        const char* path = luaL_checklstring(L, i, &len);

        if (path::Path(path, len).isabs()) {
            // Path is absolute, reset the buffer length
            b.n = 0;
        }
        else {
            // Path is relative, add path separator if necessary.
            if (b.n > 0 && !path::issep(b.b[b.n-1]))
                luaL_addchar(&b, path::defaultSep);
        }

        luaL_addlstring(&b, path, len);
    }

    luaL_pushresult(&b);
    return 1;
}

static int path_split(lua_State* L) {

    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    path::Split s = path::split(path::Path(path, len));

    lua_pushlstring(L, s.head.path, s.head.length);
    lua_pushlstring(L, s.tail.path, s.tail.length);

    return 2;
}

static int path_basename(lua_State* L) {
    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    path::Split s = path::split(path::Path(path, len));
    lua_pushlstring(L, s.tail.path, s.tail.length);
    return 1;
}

static int path_dirname(lua_State* L) {
    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    path::Split s = path::split(path::Path(path, len));
    lua_pushlstring(L, s.head.path, s.head.length);
    return 1;
}

static int path_splitext(lua_State* L) {

    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    path::Split s = path::splitExtension(path::Path(path, len));

    lua_pushlstring(L, s.head.path, s.head.length);
    lua_pushlstring(L, s.tail.path, s.tail.length);

    return 2;
}

static int path_getext(lua_State* L) {
    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    path::Split s = path::splitExtension(path::Path(path, len));

    lua_pushlstring(L, s.tail.path, s.tail.length);
    return 1;
}

static int path_norm(lua_State* L) {

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
