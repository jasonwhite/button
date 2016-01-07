/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Globbing.
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
bool globMatch(path::Path path, path::Path pattern) {

    size_t i = 0;

    for (size_t j = 0; j < pattern.length; ++j) {
        switch (pattern.path[j]) {
            case '?': {
                // Match any single character
                if (i == path.length)
                    return false;
                ++i;
                break;
            }

            case '*': {
                // Match 0 or more characters
                if (j+1 == pattern.length)
                    return true;

                // Consume characters while looking ahead for matches
                for (; i < path.length; ++i) {
                    if (globMatch<CaseSensitive>(
                                path::Path(path.path+i, path.length-i),
                                path::Path(pattern.path+j+1, pattern.length-j-1)))
                        return true;
                }

                return false;
            }

            case '[': {
                // Match any of the characters that appear in the square brackets
                if (i == path.length) return false;

                // Skip past the opening bracket
                if (++j == pattern.length) return false;

                // Invert the match?
                bool invert = false;
                if (pattern.path[j] == '!') {
                    invert = true;
                    if (++j == pattern.length)
                        return false;
                }

                // Find the closing bracket
                size_t end = j;
                while (end < pattern.length && pattern.path[end] != ']')
                    ++end;

                // No matching bracket?
                if (end == pattern.length) return false;

                // Check each character between the brackets for a match
                bool match = false;
                while (j < end) {
                    // Found a match
                    if (!match && charCmp<CaseSensitive>(path.path[i], pattern.path[j]) == 0) {
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
                if (i == path.length || charCmp<CaseSensitive>(path.path[i], pattern.path[j]))
                    return false;
                ++i;
                break;
            }
        }
    }

    // If we ran out of pattern and out of path, then we have a complete match.
    return i == path.length;
}

bool globMatch(path::Path path, path::Path pattern) {
#ifdef _WIN32
    return globMatch<false>(path, pattern);
#else
    return globMatch<true>(path, pattern);
#endif
}

/**
 * Returns true if the given string contains a glob pattern.
 */
bool isGlobPattern(path::Path p) {
    for (size_t i = 0; i < p.length; ++i) {
        switch (p.path[i]) {
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
bool isRecursiveGlob(path::Path p) {
    return p.length == 2 && p.path[0] == '*' && p.path[1] == '*';
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

typedef void (*GlobCallback)(path::Path path, bool isDir, void* data);

struct GlobClosure {
    path::Path pattern;

    // Next callback
    GlobCallback next;
    void* nextData;
};

/**
 * Helper function for listing a directory with the given pattern. If the
 * pattern is empty,
 */
void glob(path::Path path, path::Path pattern,
          GlobCallback callback, void* data) {

    std::string buf(path.path, path.length);

    if (pattern.length == 0) {
        path::join(buf, pattern);
        callback(path::Path(buf.data(), buf.size()), true, data);
        return;
    }

    struct dirent* entry;
    DIR* dir = opendir(path.length > 0 ? buf.c_str() : ".");
    if (!dir)
        return;

    // TODO: Implement this for windows, too.
    while ((entry = readdir(dir))) {
        const char* name = entry->d_name;
        size_t nameLength = strlen(entry->d_name);
        bool isDir = entry->d_type == DT_DIR;

        if (isHiddenDir(name, nameLength))
            continue;

        if (globMatch(path::Path(name, nameLength), pattern)) {
            path::join(buf, path::Path(entry->d_name, nameLength));

            callback(path::Path(buf.data(), buf.size()), isDir, data);

            buf.assign(path.path, path.length);
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

    // "**" matches 0 or more directories and thus includes this one.
    callback(path::Path(path.data(), path.size()), true, data);

    // TODO: Implement this for windows, too.
    while ((entry = readdir(dir))) {
        const char* name = entry->d_name;
        size_t nameLength = strlen(entry->d_name);
        bool isDir = entry->d_type == DT_DIR;

        if (isHiddenDir(name, nameLength))
            continue;

        path::join(path, path::Path(entry->d_name, nameLength));

        callback(path::Path(path.data(), path.size()), isDir, data);

        if (isDir)
            globRecursive(path, callback, data);

        path.resize(len);
    }

    closedir(dir);
}

void globCallback(path::Path path, bool isDir, void* data) {
    if (isDir) {
        const GlobClosure* c = (const GlobClosure*)data;
        glob(path, c->pattern, c->next, c->nextData);
    }
}

/**
 * Glob a directory.
 */
void glob(path::Path path, GlobCallback callback, void* data = NULL) {

    path::Split s = path::split(path);

    if (isGlobPattern(s.head)) {
        // Directory name contains a glob pattern

        GlobClosure c;
        c.pattern = s.tail;
        c.next = callback;
        c.nextData = data;

        glob(s.head, &globCallback, &c);
    }
    else if (isRecursiveGlob(s.tail)) {
        std::string buf(s.head.path, s.head.length);
        globRecursive(buf, callback, data);
    }
    else if (isGlobPattern(s.tail)) {
        // Only base name contains a glob pattern.
        glob(s.head, s.tail, callback, data);
    }
    else {
        // No glob pattern in this path.
        if (s.tail.length) {
            // TODO: If file exists, then return it
            callback(path, false, data);
        }
        else {
            // TODO: If directory exists, then return it
            callback(s.head, true, data);
        }
    }
}

/**
 * Callback to put globbed items into a set.
 */
void fs_globcallback(path::Path path, bool isDir, void* data) {
    std::set<std::string>* paths = (std::set<std::string>*)data;
    paths->insert(std::string(path.path, path.length));
}

/**
 * Callback to remove globbed items from a set.
 */
void fs_globcallback_exclude(path::Path path, bool isDir, void* data) {
    std::set<std::string>* paths = (std::set<std::string>*)data;
    paths->erase(std::string(path.path, path.length));
}

/**
 * Lua wrapper to prepend the current script directory to the requested path.
 */
void glob(lua_State* L, path::Path path, GlobCallback callback, void* data) {

    // Join the SCRIPT_DIR with this path.
    lua_getglobal(L, "path");
    lua_getfield(L, -1, "join");
    lua_getglobal(L, "SCRIPT_DIR");
    lua_pushlstring(L, path.path, path.length);
    lua_call(L, 2, 1);

    size_t len;
    const char* scriptDir = lua_tolstring(L, -1, &len);

    if (scriptDir)
        glob(path::Path(scriptDir, len), callback, data);

    lua_pop(L, 2); // Pop new path and path table
}

} // anonymous namespace

int lua_glob_match(lua_State* L) {
    size_t len, patlen;
    const char* path = luaL_checklstring(L, 1, &len);
    const char* pattern = luaL_checklstring(L, 2, &patlen);
    lua_pushboolean(L, globMatch(path::Path(path, len), path::Path(pattern, patlen)));
    return 1;
}

int lua_glob(lua_State* L) {

    // TODO: Cache results of a directory listing and use that for further globs.

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
                        glob(L, path::Path(path+1, len-1), &fs_globcallback_exclude, &paths);
                    else
                        glob(L, path::Path(path, len), &fs_globcallback, &paths);
                }

                lua_pop(L, 1); // Pop path
            }
        }
        else if (type == LUA_TSTRING) {
            path = luaL_checklstring(L, i, &len);

            if (len > 0 && path[0] == '!')
                glob(L, path::Path(path+1, len-1), &fs_globcallback_exclude, &paths);
            else
                glob(L, path::Path(path, len), &fs_globcallback, &paths);
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
