--[[
 Copyright: Copyright Jason White, 2015
 License:   MIT
 Authors:   Jason White

 Description:
 Generates rules for GCC.
]]

local rules = require "rules"

local cc_srcs = {".c", ".cc", ".cpp", ".cxx", ".c++.C"}
local cc_hdrs = {".h", ".hh", ".hpp", ".hxx", ".inc"}

local function is_cc_source(f)
    local _, ext = path.splitext(f)
    return table.contains(cc_srcs, ext)
end

local function is_cc_header(f)
    local _, ext = path.splitext(f)
    return table.contains(cc_hdrs, ext)
end

local function to_object(objdir, src)
    return path.join(objdir, src .. ".o")
end


--[[
Base metatable.
]]
local common = {
    -- Path to GCC
    compiler = {"gcc"};

    -- Extra options to always pass to the compiler.
    opts = {};

    -- Path to the bin directory
    bindir = "./bin";

    -- Additional include directories.
    includes = {},

    -- Preprocessor definitions.
    defines = {},
}

--[[
Returns the path to the target
]]
function common:path()
    return path.join(self.bindir, self.name)
end

setmetatable(common, {__index = rules.common})


--[[
A binary executable.
]]
local _binary = {}
local _binary_mt = {__index = _binary}

local function is_binary(t)
    return getmetatable(t) == _binary_mt
end

setmetatable(_binary, {__index = common})

local function binary(opts)
    setmetatable(opts, _binary_mt)
    return rules.add(opts)
end


--[[
A library. Can be shared, static, or both (default).
]]
local _library = {
    -- Link a shared library?
    shared = true,

    -- Link a static static library?
    static = true,
}

local _library_mt = {__index = _library}

local function is_library(t)
    return getmetatable(t) == _library_mt
end

setmetatable(_library, {__index = common})

local function library(opts)
    setmetatable(opts, _library_mt)
    return rules.add(opts)
end


function common:rules(deps)
    local objdir = self.objdir or path.join("obj", self.name)
    local args = table.join(self.prefix, self.compiler, self.opts)

    local compiler_opts = {}

    for _,v in ipairs(self.includes) do
        table.append(compiler_opts, {"-I", v})
    end

    for _,v in ipairs(self.defines) do
        table.append(compiler_opts, {"-D", v})
    end

    table.append(compiler_opts, self.compiler_opts)

    local sources = {}
    local objects = {}
    for _,v in ipairs(self.srcs) do
        if is_cc_source(v) then
            table.insert(sources, v)
            table.insert(objects, to_object(objdir, v))
        end
    end

    local output = self:path()

    for i,src in ipairs(sources) do
        rule {
            inputs  = {src},
            task    = table.join(args, compiler_opts, {"-c", src, "-o", objects[i]}),
            outputs = {objects[i]},
        }
    end

    local linker_opts = table.join(self.linker_opts, {"-o", output})

    rule {
        inputs  = objects,
        task    = table.join(args, linker_opts, objects),
        outputs = {output},
    }
end

function _library:path()
    local name = common.path(self)

    if self.shared then
        return path.join(self.bindir, "lib".. name .. ".so")
    else
        return path.join(self.bindir, "lib".. name .. ".a")
    end
end

function _library:rules(deps)
    if self.shared then
        self.linker_opts = table.join(self.linker_opts, "-shared")
    else
        self.linker_opts = table.join(self.linker_opts, "-lib")
    end

    common.rules(self, deps)
end

return {
    common = common;

    is_binary  = is_binary,
    is_library = is_library,

    binary  = binary,
    library = library,
}
