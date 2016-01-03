#!/bin/sh -e
# Copyright (c) 2016 Jason White
# MIT License

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

bblua glob.lua -o /dev/null "$tempdir"
