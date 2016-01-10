--[[
Copyright (c) Jason White. MIT license.

Description:
This file is the first Lua script that gets executed. Its job is to initialize
the global Lua state for client scripts.
]]

-- Remove functions that can affect the file system.
io.popen   = nil
io.tmpfile = nil
io.output  = nil

os.execute = nil
os.tmpname = nil
os.rename  = nil
os.remove  = nil

package.loadlib = nil

-- Remove functions that can introduce non-determinism.
math.random     = nil
math.randomseed = nil

--[[
    Override io.open to prevent writing to files and to provide dependency
    information to the host build system.
]]
local _open = io.open
io.open = function(filename, mode)
    if mode ~= "" and mode ~= "r" and mode ~= "rb" then
        error("can only open files in read mode")
    end

    publish_input(filename)

    return _open(filename, mode)
end

--[[
    Wrap dofile to provide dependency information to the host build system.
]]
local _loadfile = loadfile
function loadfile(...)
    local filename = ...
    if filename ~= nil then
        publish_input(filename)
    end

    _loadfile(...)
end

--[[
    Wrap dofile to provide dependency information to the host build system.
]]
local _dofile = dofile
function dofile(...)
    local filename = ...
    if filename ~= nil then
        publish_input(filename)
    end

    _dofile(...)
end

--[[
    Wrap package.searchers[2] to provide dependency information to the host build
    system.
]]
local _searcher = package.searchers[2]
package.searchers[2] = function(module)
    local loader, fname = _searcher(module)

    if type(loader) == "function" then
        publish_input(fname)
        return loader, fname
    end

    return loader
end

--[[
    Import the rules from another build script.

    TODO: Send back dependency on this file
]]
function import(file)
    local old_dir = SCRIPT_DIR
    SCRIPT_DIR = path.dirname(file)

    dofile(path.join(old_dir, file))

    SCRIPT_DIR = old_dir
end

--[[
 Original Author: Julio Manuel Fernandez-Diaz

 Formats tables with cycles recursively to any depth. The output is returned as
 a string. References to other tables are shown as values. Self references are
 indicated.

 The string returned is "Lua code", which can be procesed (in the case in which
 indent is composed by spaces or "--"). Userdata and function keys and values
 are shown as strings, which logically are exactly not equivalent to the
 original code.

 This routine can serve for pretty formating tables with proper indentations,
 apart from printing them:

    print(table.show(t, "t"))   -- a typical use

 Heavily based on "Saving tables with cycles", PIL2, p. 113.

 Arguments:
    t is the table.
    name is the name of the table (optional)
    indent is a first indentation (optional).
--]]
function table.show(t, name, indent)
    local cart     -- a container
    local autoref  -- for self references

    local function basicSerialize(o)
        local so = tostring(o)
        if type(o) == "function" then
            local info = debug.getinfo(o, "S")
            -- info.name is nil because o is not a calling level
            if info.what == "C" then
                return string.format("%q", so .. ", C function")
            else
                -- the information is defined through lines
                return string.format("%q", so .. ", defined in (" ..
                    info.linedefined .. "-" .. info.lastlinedefined ..
                    ")" .. info.source)
            end
        elseif type(o) == "number" or type(o) == "boolean" then
            return so
        else
            return string.format("%q", so)
        end
    end

    local function addtocart(value, name, indent, saved, field)
        indent = indent or ""
        saved = saved or {}
        field = field or name

        cart = cart .. indent .. field

        if type(value) ~= "table" then
            cart = cart .. " = " .. basicSerialize(value) .. ";\n"
        else
            if saved[value] then
                cart = cart .. " = {}; -- " .. saved[value]
                .. " (self reference)\n"
                autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
            else
                saved[value] = name
                if next(value) == nil then
                    cart = cart .. " = {};\n"
                else
                    cart = cart .. " = {\n"
                    for k, v in pairs(value) do
                        k = basicSerialize(k)
                        local fname = string.format("%s[%s]", name, k)
                        field = string.format("[%s]", k)
                        addtocart(v, fname, indent .. "    ", saved, field)
                    end
                    cart = cart .. indent .. "};\n"
                end
            end
        end
    end

    name = name or "__unnamed__"
    if type(t) ~= "table" then
        return name .. " = " .. basicSerialize(t)
    end
    cart, autoref = "", ""
    addtocart(t, name, indent)
    return cart .. autoref
end

function table.print(t, name, indent)
    print(table.show(t, name, indent))
end

function table.append(t, ...)
    for _,i in ipairs({...}) do
        if type(i) == "table" then
            for _,j in ipairs(i) do
                table.insert(t, j)
            end
        else
            table.insert(t, i)
        end
    end

    return t
end

function table.join(...)
    local t = {}
    return table.append(t, ...)
end

--[[
Checks if the given table contains the given value. Returns true if the value is
in the table, false otherwise.
]]
function table.contains(t, value)
    for _,v in ipairs(t) do
        if v == value then
            return true
        end
    end

    return false
end
