#!/bin/sh -e
# Copyright (c) 2016 Jason White
# MIT License
#
# Description:
# Tests additions to the standard Lua library.

bblua std/globals.lua -o /dev/null
bblua std/path.lua -o /dev/null
bblua std/fs.lua -o /dev/null

# Create the directory structure
tempdir=$(mktemp -d)

teardown() {
    rm -rf -- "$tempdir"
}

# Cleanup on exit
trap teardown 0

mkdir -- "$tempdir/a" \
         "$tempdir/b" \
         "$tempdir/c"

# Create nested sub directories
mkdir -- "$tempdir/c/1" \
         "$tempdir/c/2" \
         "$tempdir/c/3"

touch -- "$tempdir/a/foo.c" \
         "$tempdir/a/foo.h" \
         "$tempdir/b/bar.c" \
         "$tempdir/b/bar.h" \
         "$tempdir/c/baz.h" \
         "$tempdir/c/1/foo.cc" \
         "$tempdir/c/2/bar.cc" \
         "$tempdir/c/3/baz.cc" \

bblua std/glob.lua -o /dev/null "$tempdir"
