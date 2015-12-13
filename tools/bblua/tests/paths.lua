
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
local h, t

h, t = path.split("")
assert(h == "" and t == "")

h, t = path.split("/")
assert(h == "/" and t == "")

h, t = path.split("/foo")
assert(h == "/" and t == "foo")

h, t = path.split("foo/bar")
assert(h == "foo" and t == "bar")

h, t = path.split("/foo////bar")
assert(h == "/foo" and t == "bar")

h, t = path.split("////foo////bar")
assert(h == "////foo" and t == "bar")


--[[
    path.basename
]]
assert(path.basename("") == "")
assert(path.basename("/") == "")
assert(path.basename("/foo") == "foo")
assert(path.basename("/foo/bar") == "bar")
assert(path.basename("////foo////bar") == "bar")
assert(path.basename("/foo/bar/") == "")
