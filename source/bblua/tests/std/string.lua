--[[
Copyright 2016 Jason White. MIT license.

Description:
Tests additions to the string library.
]]

assert(string.glob("", ""))
assert(string.glob("", "*"))
assert(string.glob("foo", "foo"))
assert(string.glob("foo.c", "*.c"))
assert(string.glob("foo", "foo*"))
assert(string.glob("foo.bar.baz", "*.*.*"))
assert(string.glob("foo.bar.baz", "f*.b*.b*"))
assert(string.glob("foo", "[bf]oo"))
assert(string.glob("zoo", "[!bf]oo"))
assert(string.glob("foo.c", "[fb]*.c"))

assert(not string.glob("", "a"))
assert(not string.glob("a", ""))
assert(not string.glob("foo", "bar"))
assert(not string.glob("foo.bar", "foo"))
assert(not string.glob("foo.d", "*.c"))
assert(not string.glob("foo.bar.baz", "f*.f*.f*"))
assert(not string.glob("zoo", "[bf]oo"))
assert(not string.glob("zoo", "[!bzf]oo"))
