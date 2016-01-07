--[[
Copyright 2016 Jason White. MIT license.

Description:
Tests the path manipulation functions.
]]

--[[
    path.isabs
]]
assert(path.isabs("/"))
assert(path.isabs("/foo/bar"))
assert(not path.isabs("foo"))
assert(not path.isabs(""))


--[[
    path.join
]]
assert(path.join() == "")
assert(path.join("") == "")
assert(path.join("", "") == "")
assert(path.join("foo") == "foo")
assert(path.join("foo", "bar") == "foo/bar")
assert(path.join("foo", "/bar") == "/bar")
assert(path.join("foo/", "bar") == "foo/bar")
assert(path.join("foo/", nil, "bar") == "foo/bar")
assert(path.join("foo//", "bar") == "foo//bar")
assert(path.join("/", "foo") == "/foo")
assert(path.join("foo", "") == "foo/")
assert(path.join("foo", nil) == "foo")


--[[
    path.split
]]

local split_tests = {
    {"", "", "", ""},
    {"/", "/", "", "/"},
    {"/foo", "/", "foo", "/foo"},
    {"foo/bar", "foo", "bar", "foo/bar"},
    {"foo/", "foo", "", "foo/"},
    {"/foo////bar", "/foo", "bar", "/foo/bar"},
    {"////foo////bar", "////foo", "bar", "////foo/bar"},
}

local split_error = 'In path.split("%s"): expected "%s", got "%s"'

for k,v in ipairs(split_tests) do
    local head, tail = path.split(v[1])
    assert(head == v[2], string.format(split_error, v[1], head, v[2]))
    assert(tail == v[3], string.format(split_error, v[1], tail, v[3]))
    assert(path.join(head, tail) == v[4])
end


--[[
    path.basename
]]
assert(path.basename("") == "")
assert(path.basename("/") == "")
assert(path.basename("/foo") == "foo")
assert(path.basename("/foo/bar") == "bar")
assert(path.basename("////foo////bar") == "bar")
assert(path.basename("/foo/bar/") == "")

--[[
    path.dirname
]]
assert(path.dirname("") == "")
assert(path.dirname("/") == "/")
assert(path.dirname("/foo") == "/")
assert(path.dirname("/foo/bar") == "/foo")
assert(path.dirname("/foo/bar/") == "/foo/bar")


--[[
    path.splitext
]]

local splitext_tests = {
    {"", "", ""},
    {"/", "/", ""},
    {"foo", "foo", ""},
    {".foo", ".foo", ""},
    {"foo.bar", "foo", ".bar"},
    {"foo/bar.baz", "foo/bar", ".baz"},
    {"foo/.bar.baz", "foo/.bar", ".baz"},
    {"foo/....bar.baz", "foo/....bar", ".baz"},
    {"/....bar", "/....bar", ""},
}

local split_error = 'In path.splitext("%s"): expected "%s", got "%s"'

for k,v in ipairs(splitext_tests) do
    local root, ext = path.splitext(v[1])
    assert(root == v[2], string.format(split_error, v[1], root, v[2]))
    assert(ext  == v[3], string.format(split_error, v[1], ext, v[3]))
    assert(root .. ext == v[1])
end

--[[
    path.getext
]]

assert(path.getext("") == "")
assert(path.getext("/") == "")
assert(path.getext("/foo") == "")
assert(path.getext("/foo.") == ".")
assert(path.getext("/foo.bar") == ".bar")
assert(path.getext("/.foo.bar") == ".bar")
