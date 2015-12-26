/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Path manipulation module.
 */
#pragma once

#include <stddef.h> // For size_t

struct lua_State;

namespace path {

/**
 * Posix paths use forward slashes ('/') as directory separators. Absolute paths
 * begin with a directory separator.
 */
#define PATH_STYLE_POSIX 0

/**
 * Windows (not DOS!) paths use backslashes ('\') or forward slashes ('/') as
 * directory separators. Drive letters can be prepended to either absolute or
 * relative paths. Networked (UNC) paths begin with a double backslash ("\\").
 */
#define PATH_STYLE_WINDOWS 1

#ifndef PATH_STYLE
#   ifdef _WIN32
#       define PATH_STYLE PATH_STYLE_WINDOWS
#   else
#       define PATH_STYLE PATH_STYLE_POSIX
#   endif
#endif

#if PATH_STYLE == PATH_STYLE_WINDOWS

const char defaultSep = '\\';
const bool caseSensitive = false;

inline bool issep(char c) {
    return c == '/' || c == '\\';
}

#else

const char defaultSep = '/';
const bool caseSensitive = true;

inline bool issep(char c) {
    return c == '/';
}

#endif

/**
 * Compare two characters. The comparison is case insensitive for Windows style
 * paths.
 */
int cmp(char a, char b);

/**
 * Compares two paths for equality.
 */
int cmp(const char* a, const char* b, size_t len);
int cmp(const char* a, const char* b, size_t len1, size_t len2);

/**
 * Returns true if the given path is absolute.
 */
bool isabs(const char* path, size_t len);

/**
 * Helper struct for representing a split path.
 */
struct Split {
    const char* head;
    size_t headlen;

    const char* tail;
    size_t taillen;
};

/**
 * Splits a path such that the head is the parent directory (empty if none) and
 * the tail is the basename of the file path.
 */
Split split(const char* path, size_t len);

}

/**
 * Pushes the path library onto the stack so that it can be registered.
 */
int luaopen_path(lua_State* L);
