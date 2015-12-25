/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Globbing.
 *
 * TODO: Cache results of a directory listing and use that for further globs.
 */
#include "glob.h"

#include "lua.hpp"

#include <ctype.h>

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
 * Checks if a glob pattern matches a string.
 *
 * Arguments:
 *  - path: The path to match
 *  - pattern: The glob pattern
 *
 * Returns: True if it matches, false otherwise.
 */
int glob_match(lua_State* L) {
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
 */
int glob_glob(lua_State* L) {

    int argc = lua_gettop(L);

    //size_t len;
    //const char* pattern;

    for (int i = 1; i <= argc; ++i) {
        //pattern = luaL_checklstring(L, i, &len);

        // TODO: Construct a set of matched files
    }

    return 0;
}

static const luaL_Reg globlib[] = {
    {"match", glob_match},
    {"glob", glob_glob},
    {NULL, NULL},
};

int luaopen_glob(lua_State* L) {
    luaL_newlib(L, globlib);
    return 1;
}
