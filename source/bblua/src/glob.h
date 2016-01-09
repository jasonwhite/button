/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Globbing.
 */
#pragma once

struct lua_State;

/**
 * Checks if a glob pattern matches a string.
 *
 * Arguments:
 *  - path: The path to match
 *  - pattern: The glob pattern
 *
 * Returns: True if it matches, false otherwise.
 */
int lua_glob_match(lua_State* L);

/**
 * Lists files based on a glob expression.
 *
 * Arguments:
 *  - pattern: A pattern string or table of pattern strings
 *
 * Returns: A table of the matching files.
 */
int lua_glob(lua_State* L);
