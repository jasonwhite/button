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
#include <string.h> // for strlen
#include <string>

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

struct Path {

    Path() : path(NULL), length(0) {}
    Path(const char* path) : path(path), length(strlen(path)) {}
    Path(const char* path, size_t length) : path(path), length(length) {}

    const char* path;
    size_t length;

    /**
     * Returns true if the given path is absolute.
     */
    bool isabs() const;

    Path dirname() const;
    Path basename() const;

    std::string copy() const;
};

/**
 * Helper struct for representing a split path.
 */
struct Split {
    Path head;
    Path tail;
};

/**
 * Splits a path such that the head is the parent directory (empty if none) and
 * the tail is the basename of the file path.
 */
Split split(Path path);

/**
 * Splits a path into an extension.
 */
Split splitExtension(Path path);

/**
 * Joins two paths.
 */
std::string& join(std::string& buf, Path path);

}

/**
 * Pushes the path library onto the stack so that it can be registered.
 */
int luaopen_path(lua_State* L);
