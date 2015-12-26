/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * File system module.
 */
#include "glob.h"

#include "lua.hpp"

#include <string.h>
#include <ctype.h>
#include <dirent.h>
#include <errno.h>

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
/*bool isGlobPattern(const char* s, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        switch (s[i]) {
            case '?':
            case '*':
            case '[':
                return true;
        }
    }

    return false;
}*/

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
 * Lists files based on a glob expression.
 *
 * Arguments:
 *  - pattern: A pattern string or table of pattern strings
 *
 * Returns: A table of the matching files.
 *
 * TODO: Cache results of a directory listing and use that for further globs.
 */
static int fs_glob(lua_State* L) {

    int argc = lua_gettop(L);

    lua_newtable(L);

    //size_t len;
    struct dirent* entry;
    const char* pattern;

    lua_Number n = 1;

    for (int i = 1; i <= argc; ++i) {
        pattern = luaL_checkstring(L, i);

        DIR* dir = opendir(pattern);
        if (dir) {
            while ((entry = readdir(dir))) {
                if (entry->d_type == DT_REG) {
                    // TODO:
                    lua_pushlstring(L, entry->d_name, strlen(entry->d_name));
                    lua_seti(L, -2, n);
                    ++n;
                }
            }

            closedir(dir);
        }
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
    const char* path = luaL_checkstring(L, 1);

    lua_newtable(L);

    struct dirent* entry;

    lua_Number i = 1;
    DIR* dir = opendir(path);
    if (!dir) {
        lua_pushnil(L);
        lua_pushfstring(L, "failed to list directory `%s`: %s", path, strerror(errno));
        return 2;
    }

    while ((entry = readdir(dir))) {
        if (entry->d_type == DT_REG) {
            lua_pushstring(L, entry->d_name);
            lua_seti(L, -2, i);
            ++i;
        }
    }

    closedir(dir);

    return 1;
}

const luaL_Reg fslib[] = {
    {"globmatch", fs_globmatch}, // TODO: Remove this later
    {"glob", fs_glob},
    {"listdir", fs_listdir},
    {NULL, NULL},
};

} // anonymous namespace

int luaopen_fs(lua_State* L) {
    luaL_newlib(L, fslib);
    return 1;
}
