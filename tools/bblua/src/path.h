/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Path manipulation module.
 */
#pragma once

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

static inline bool issep(char c) {
    return c == '/' || c == '\\';
}

#else

const char defaultSep = '/';
const bool caseSensitive = true;

static inline bool issep(char c) {
    return c == '/';
}

#endif

/**
 * Returns true if the path is absolute, false otherwise.
 */
int isabs(lua_State* L);

/**
 * Returns a path with all path elements joined together.
 */
int join(lua_State* L);

/**
 * Returns the head and tail of the path where the tail is the last path
 * element and the head is everything leading up to it.
 */
int split(lua_State* L);

/**
 * Returns the last path element. This is the same as the tail of path_split().
 */
int basename(lua_State* L);

/**
 * Returns the everything except for the basename of the path. This is the same
 * as the head of path_split().
 */
int dirname(lua_State* L);

/**
 * Splits the path into a root and extension such that concatenating the root
 * and extension returns the original path.
 */
int splitext(lua_State* L);

/**
 * Returns the extension of the path. This is the same as splitting by extension
 * and retrieving just the extension part.
 */
int getext(lua_State* L);

/**
 * Normalizes the path such that redundant path separators and up=level
 * references are collapsed.
 */
int norm(lua_State* L);

/**
 * Pushes the path library onto the stack so that it can be registered.
 */
int luaopen(lua_State* L);

}
