#!/bin/sh -e
# Copyright (c) 2016 Jason White
# MIT License
#
# Description:
# Tests additions to the standard Lua library.

runtest std/globals.sh
runtest std/path.sh
runtest std/fs.sh
runtest std/glob.sh
