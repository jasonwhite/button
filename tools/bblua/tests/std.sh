#!/bin/sh -e
# Copyright (c) 2016 Jason White
# MIT License
#
# Description:
# Tests additions to the standard Lua library.

bblua std/removed.lua -o /dev/null
bblua std/path.lua -o /dev/null
