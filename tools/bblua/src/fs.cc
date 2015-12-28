/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * File system module.
 */
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <unistd.h>

#include <string>
#include <set>

#include "lua.hpp"

#include "glob.h"
#include "path.h"

namespace {

/**
 * Compare a character with case sensitivity or not.
 */
template <bool CaseSensitive>
static int charCmp(char a, char b) {
    if (CaseSensitive)
        return (int)a - (int)b;
    else
        return (int)tolower(a) - (int)tolower(b);
}

/**
 * Returns true if the pattern matches the given filename, false otherwise.
 */
template <bool CaseSensitive>
bool globMatch(const char* path, size_t len, const char* pattern, size_t patlen) {

    size_t i = 0;

    for (size_t j = 0; j < patlen; ++j) {
        switch (pattern[j]) {
            case '?': {
                // Match any single character
                if (i == len)
                    return false;
                ++i;
                break;
            }

            case '*': {
                // Match 0 or more characters
                if (j+1 == patlen)
                    return true;

                // Consume characters while looking ahead for matches
                for (; i < len; ++i) {
                    if (globMatch<CaseSensitive>(path+i, len-i, pattern+j+1, patlen-j-1))
                        return true;
                }

                return false;
            }

            case '[': {
                // Match any of the characters that appear in the square brackets
                if (i == len) return false;

                // Skip past the opening bracket
                if (++j == patlen) return false;

                // Invert the match?
                bool invert = false;
                if (pattern[j] == '!') {
                    invert = true;
                    if (++j == patlen)
                        return false;
                }

                // Find the closing bracket
                size_t end = j;
                while (end < patlen && pattern[end] != ']')
                    ++end;

                // No matching bracket?
                if (end == patlen) return false;

                // Check each character between the brackets for a match
                bool match = false;
                while (j < end) {
                    // Found a match
                    if (!match && charCmp<CaseSensitive>(path[i], pattern[j]) == 0) {
                        match = true;
                    }

                    ++j;
                }

                if (match == invert)
                    return false;

                ++i;
                break;
            }

            default: {
                // Match the next character in the pattern
                if (i == len || charCmp<CaseSensitive>(path[i], pattern[j]))
                    return false;
                ++i;
                break;
            }
        }
    }

    // If we ran out of pattern and out of path, then we have a complete match.
    return i == len;
}

bool globMatch(const char* path, size_t len, const char* pattern, size_t patlen) {
#ifdef _WIN32
    return globMatch<false>(path, len, pattern, patlen);
#else
    return globMatch<true>(path, len, pattern, patlen);
#endif
}

/**
 * Returns true if the given string contains a glob pattern.
 */
bool isGlobPattern(const char* s, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        switch (s[i]) {
            case '?':
            case '*':
            case '[':
                return true;
        }
    }

    return false;
}

/**
 * Returns true if the given path element is a recursive glob pattern.
 */
bool isRecursiveGlob(const char* s, size_t len) {
    return len == 2 && s[0] == '*' && s[1] == '*';
}

/**
 * Returns true if the given path element is a hidden directory (i.e., "." or
 * "..").
 */
bool isHiddenDir(const char* s, size_t len) {
    switch (len) {
        case 1:
            return s[0] == '.';
        case 2:
            return s[0] == '.' && s[1] == '.';
        default:
            return false;
    }
}

typedef void (*GlobCallback)(const char* path, size_t len, bool isDir, void* data);

struct GlobClosure {
    const char* pattern;
    size_t patternLength;

    // Next callback
    GlobCallback next;
    void* nextData;
};

/**
 * Helper function for listing a directory with the given pattern. If the
 * pattern is empty,
 */
void glob(const char* path, size_t len,
          const char* pattern, size_t patlen,
          GlobCallback callback, void* data) {

    std::string buf(path, len);

    if (patlen == 0) {
        path::join(buf, pattern, patlen);
        callback(buf.data(), buf.size(), true, data);
        return;
    }

    struct dirent* entry;
    DIR* dir = opendir(len > 0 ? buf.c_str() : ".");
    if (!dir)
        return;

    // TODO: Implement this for windows, too.
    while ((entry = readdir(dir))) {
        const char* name = entry->d_name;
        size_t nameLength = strlen(entry->d_name);
        bool isDir = entry->d_type == DT_DIR;

        if (isHiddenDir(name, nameLength))
            continue;

        if (globMatch(name, nameLength, pattern, patlen)) {
            path::join(buf, entry->d_name, nameLength);

            callback(buf.data(), buf.size(), isDir, data);

            buf.assign(path, len);
        }
    }

    closedir(dir);
}

/**
 * Helper function to recursively yield directories for the given path.
 */
void globRecursive(std::string& path, GlobCallback callback, void* data) {

    size_t len = path.size();

    struct dirent* entry;
    DIR* dir = opendir(len > 0 ? path.c_str() : ".");
    if (!dir)
        return;

    // TODO: Implement this for windows, too.
    while ((entry = readdir(dir))) {
        const char* name = entry->d_name;
        size_t nameLength = strlen(entry->d_name);
        bool isDir = entry->d_type == DT_DIR;

        if (isHiddenDir(name, nameLength))
            continue;

        path::join(path, entry->d_name, nameLength);

        callback(path.data(), path.size(), isDir, data);

        if (isDir)
            globRecursive(path, callback, data);

        path.resize(len);
    }

    closedir(dir);
}

void globCallback(const char* path, size_t len, bool isDir, void* data) {
    if (isDir) {
        const GlobClosure* c = (const GlobClosure*)data;
        glob(path, len, c->pattern, c->patternLength, c->next, c->nextData);
    }
}

/**
 * Glob a directory.
 */
void glob(const char* path, size_t len, GlobCallback callback, void* data = NULL) {

    path::Split s = path::split(path, len);

    if (isGlobPattern(s.head, s.headlen)) {
        // Directory name contains a glob pattern

        GlobClosure c;
        c.pattern = s.tail;
        c.patternLength = s.taillen;
        c.next = callback;
        c.nextData = data;

        glob(s.head, s.headlen, &globCallback, &c);
    }
    else if (isRecursiveGlob(s.tail, s.taillen)) {
        std::string buf(s.head, s.headlen);
        globRecursive(buf, callback, data);
    }
    else if (isGlobPattern(s.tail, s.taillen)) {
        // Only base name contains a glob pattern.
        glob(s.head, s.headlen, s.tail, s.taillen, callback, data);
    }
    else {
        // No glob pattern in this path.
        if (s.taillen) {
            // TODO: If file exists, then return it
            callback(path, len, false, data);
        }
        else {
            // TODO: If directory exists, then return it
            callback(s.head, s.headlen, true, data);
        }
    }
}

/**
 * Checks if a glob pattern matches a string.
 *
 * Arguments:
 *  - path: The path to match
 *  - pattern: The glob pattern
 *
 * Returns: True if it matches, false otherwise.
 */
int fs_globmatch(lua_State* L) {
    size_t len, patlen;
    const char* path = luaL_checklstring(L, 1, &len);
    const char* pattern = luaL_checklstring(L, 2, &patlen);
    lua_pushboolean(L, globMatch(path, len, pattern, patlen));
    return 1;
}

/**
 * Callback to put globbed items into a set.
 */
void fs_globcallback(const char* path, size_t len, bool isDir, void* data) {
    std::set<std::string>* paths = (std::set<std::string>*)data;
    paths->insert(std::string(path, len));
}

/**
 * Callback to remove globbed items from a set.
 */
void fs_globcallback_exclude(const char* path, size_t len, bool isDir, void* data) {
    std::set<std::string>* paths = (std::set<std::string>*)data;
    paths->erase(std::string(path, len));
}

/**
 * Lists files based on a glob expression.
 *
 * Arguments:
 *  - pattern: A pattern string or table of pattern strings
 *
 * Returns: A table of the matching files.
 *
 * TODO: Cache results of a directory listing and use that for further globs.
 */
int fs_glob(lua_State* L) {

    std::set<std::string> paths;

    int argc = lua_gettop(L);

    size_t len;
    const char* path;

    for (int i = 1; i <= argc; ++i) {
        const int type = lua_type(L, i);

        if (type == LUA_TTABLE) {
            for (int j = 1; ; ++j) {
                if (lua_rawgeti(L, i, j) == LUA_TNIL) {
                    lua_pop(L, 1);
                    break;
                }

                path = lua_tolstring(L, -1, &len);
                if (path) {
                    if (len > 0 && path[0] == '!')
                        glob(path+1, len-1, &fs_globcallback_exclude, &paths);
                    else
                        glob(path, len, &fs_globcallback, &paths);
                }

                lua_pop(L, 1); // Pop path
            }
        }
        else if (type == LUA_TSTRING) {
            path = luaL_checklstring(L, i, &len);

            if (len > 0 && path[0] == '!')
                glob(path+1, len-1, &fs_globcallback_exclude, &paths);
            else
                glob(path, len, &fs_globcallback, &paths);
        }
    }

    // Construct the Lua table.
    lua_newtable(L);
    lua_Number n = 1;

    for (std::set<std::string>::iterator it = paths.begin(); it != paths.end(); ++it) {
        lua_pushlstring(L, it->data(), it->size());
        lua_seti(L, -2, n);
        ++n;
    }

    return 1;
}

/**
 * Lists files in the given directory.
 *
 * Arguments:
 *  - dir: Directory for which to list files.
 *
 * Returns: A table with the directory listing.
 *
 * TODO: Cache directory listings.
 */
int fs_listdir(lua_State* L) {
    size_t len;
    const char* path = luaL_checklstring(L, 1, &len);

    if (len == 0) {
        len = 1;
        path = ".";
    }

    lua_newtable(L);

    struct dirent* entry;

    lua_Number i = 1;
    DIR* dir = opendir(path);
    if (!dir) {
        lua_pushnil(L);
        lua_pushfstring(L, "failed to list directory '%s': %s", path, strerror(errno));
        return 2;
    }

    while ((entry = readdir(dir))) {
        // Skip "." and ".."
        if (isHiddenDir(entry->d_name, strlen(entry->d_name)))
            continue;

        if (entry->d_type == DT_REG) {
            lua_pushstring(L, entry->d_name);
            lua_seti(L, -2, i);
            ++i;
        }
    }

    closedir(dir);

    return 1;
}

int fs_getcwd(lua_State* L) {

    char* p = getcwd(NULL, 0);
    if (!p)
        return luaL_error(L, "getcwd failed");

    lua_pushstring(L, p);

    free(p);

    return 1;
}

const luaL_Reg fslib[] = {
    {"globmatch", fs_globmatch}, // TODO: Remove this later
    {"glob", fs_glob},
    {"listdir", fs_listdir},
    {"getcwd", fs_getcwd},
    {NULL, NULL},
};

} // anonymous namespace

int luaopen_fs(lua_State* L) {
    luaL_newlib(L, fslib);
    return 1;
}
