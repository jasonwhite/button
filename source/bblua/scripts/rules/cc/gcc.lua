--[[
Copyright (c) Jason White. MIT license.

Description:
Generates rules for compiling and linking C/C++ with gcc.
]]

local rules = require "rules"

--[[
    Helper functions.
]]
local cc_srcs = {".cc", ".cpp", ".cxx", ".c++.C"}
local cc_hdrs = {".h", ".hh", ".hpp", ".hxx", ".inc"}

local function is_c_source(ext)
    return ext == ".c"
end

local function is_cpp_source(ext)
    return table.contains(cc_srcs, ext)
end

local function is_source(f)
    local ext = path.getext(f)
    return is_c_source(ext) or is_cpp_source(ext)
end

local function has_cpp_source(srcs)
    for _,src in ipairs(srcs) do
        if is_cpp_source(path.getext(src)) then
            return true
        end
    end

    return false
end

local function is_header(f)
    return table.contains(cc_hdrs, path.getext(f))
end

local function to_object(objdir, src)
    return path.join(objdir, src .. ".o")
end

--[[
    Returns a list of filtered C/C++ sources and their corresponding objects.
]]
local function get_sources_and_objects(srcs, objdir)
    local sources = {}
    local objects = {}
    for _,v in ipairs(srcs) do
        if is_source(v) then
            table.insert(sources, v)
            table.insert(objects, to_object(objdir, v))
        end
    end

    return sources, objects
end

--[[
    Generates the rules for compilation.

    Note that gcc is always used for compilation (instead of g++).
]]
local function compile(self)
    local objdir = self.objdir or ""
    local args = table.join(self.prefix, self.toolchain.gcc, self.opts)

    local compiler_opts = {}

    for _,v in ipairs(self.includes) do
        table.append(compiler_opts, {"-I", path.join(SCRIPT_DIR, v)})
    end

    for _,v in ipairs(self.defines) do
        table.append(compiler_opts, {"-D", v})
    end

    table.append(compiler_opts, self.compiler_opts)

    local sources, objects = get_sources_and_objects(self.srcs, objdir)

    for i,src in ipairs(sources) do
        rule {
            inputs  = {src},
            task    = table.join(args, compiler_opts, {"-c", src, "-o", objects[i]}),
            outputs = {objects[i]},
        }
    end

    return objects
end

--[[
    A toolchain is a collection of common tools. This table specifies paths to
    the tools in the GCC toolchain.
]]
local toolchain = {
    gcc = "gcc",
    ["g++"] = "g++",
    ar = "ar",
}


--[[
    Base metatable.
]]
local common = {
    -- Path to GCC.
    toolchain = toolchain,

    -- Extra options to always pass to the compiler.
    opts = {};

    -- Path to the bin directory.
    bindir = ".";

    -- Additional include directories.
    includes = {},

    -- Preprocessor definitions.
    defines = {},

    -- Extra compiler options.
    compiler_opts = {},

    -- Extra linker options.
    linker_opts = {},
}

function common:path()
    return path.join(self.bindir, self:basename())
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
    -- Create a static library instead of a shared library?
    static = false,
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

function common:rules()
    local objects = compile(self)

    local linker = has_cpp_source(self.srcs) and "g++" or "gcc"

    local output = self:path()
    local args = table.join(self.prefix, self.toolchain[linker], self.opts)
    local linker_opts = table.join(self.linker_opts, {"-o", output})

    for _,dep in ipairs(self.deps) do
        if is_library(dep) then
            table.append(linker_opts, {"-l".. common.basename(dep)})
        else
            error(string.format("Rule '%s' cannot depend on '%s'",
                self.name, dep.name))
        end
    end

    -- Create a binary executable.
    rule {
        inputs  = objects,
        task    = table.join(args, linker_opts, objects),
        outputs = {output},
    }
end

--[[
    Returns the basename of the library.
]]
function _library:basename()
    local name = common.basename(self)

    if self.static then
        return "lib".. name .. ".a"
    else
        return "lib".. name .. ".so"
    end
end

--[[
    Generates the rules for a shared or static library.
]]
function _library:rules()
    local objects = compile(self)

    local output = self:path()

    if self.static then
        -- ARchive the objects.
        --  * r: replace existing objects with the same name
        --  * c: create the archive if it doesn't exist
        --  * s: create or update the index
        --  * D: operate in deterministic mode
        rule {
            inputs  = objects,
            task    = table.join(self.prefix, {self.toolchain.ar, "rcsD"}, output, objects),
            outputs = {output},
        }
    else
        local linker = has_cpp_source(self.srcs) and "g++" or "gcc"
        local args = table.join(self.prefix, self.toolchain[linker], self.opts)
        local opts = {"-shared", "-o", output}

        for _,dep in ipairs(self.deps) do
            if is_library(dep) then
                table.append(opts, {"-l".. common.basename(dep)})
            end
        end

        table.append(opts, self.linker_opts)

        rule {
            inputs  = objects,
            task    = table.join(args, opts, objects),
            outputs = {output},
        }
    end
end

return {
    toolchain = toolchain,
    common = common,

    is_binary  = is_binary,
    is_library = is_library,

    binary  = binary,
    library = library,
}
