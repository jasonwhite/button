--[[
Copyright 2016 Jason White. MIT license.

Description:
Tests globbing.
]]

local tempdir = ...

local function p(f)
    return path.join(tempdir, f)
end

local function equal(t1, t2)
    table.sort(t1)
    table.sort(t2)

    if #t1 ~= #t2 then
        local msg = string.format(
            "Tables are not of equal length (%d != %d)", #t1, #t2)
        return false, msg
    end

    for i,v in ipairs(t1) do
        if v ~= t2[i] then
            local msg = string.format(
                "Tables are not equal ('%s' != '%s')", v, t2[i])
            return false, msg
        end
    end

    return true
end

assert(equal(
    fs.glob(p "*/*.c"),
    {
        p "a/foo.c",
        p "b/bar.c",
    }
))

assert(equal(
    fs.glob(p "*/*.[ch]"),
    {
        p "a/foo.c",
        p "a/foo.h",
        p "b/bar.c",
        p "b/bar.h",
        p "c/baz.h",
    }
))

assert(equal(
    fs.glob {p "*/*.c", p "*/*.h"},
    {
        p "a/foo.c",
        p "a/foo.h",
        p "b/bar.c",
        p "b/bar.h",
        p "c/baz.h",
    }
))

assert(equal(
    fs.glob(p "*/"),
    {
        p "a/",
        p "b/",
        p "c/",
    }
))

assert(equal(
    fs.glob(p "**/"),
    {
        p "",
        p "a/",
        p "b/",
        p "c/",
        p "c/1/",
        p "c/2/",
        p "c/3/",
    }
))

assert(equal(
    fs.glob(p "**"),
    {
        tempdir,
        p "a",
        p "a/foo.c",
        p "a/foo.h",
        p "b",
        p "b/bar.c",
        p "b/bar.h",
        p "c",
        p "c/baz.h",
        p "c/1",
        p "c/1/foo.cc",
        p "c/2",
        p "c/2/bar.cc",
        p "c/3",
        p "c/3/baz.cc",
    }
))
