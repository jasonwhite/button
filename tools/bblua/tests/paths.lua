
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
assert(path.join("foo") == "foo")
assert(path.join("foo", "bar") == "foo/bar")
assert(path.join("foo", "/bar") == "/bar")
assert(path.join("foo/", "bar") == "foo/bar")
assert(path.join("foo//", "bar") == "foo//bar")
assert(path.join("/", "foo") == "/foo")


--[[
    path.split
]]

split_tests = {
    {"", "", "", ""},
    {"/", "/", "", "/"},
    {"/foo", "/", "foo", "/foo"},
    {"foo/bar", "foo", "bar", "foo/bar"},
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
