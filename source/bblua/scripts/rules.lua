--[[
Copyright: Copyright Jason White, 2016
License:   MIT
Authors:   Jason White

Description:
High-level rule resolution. Client scripts add targets that may depend on each
other. Since these targets can be defined in any order, they are added to a list
and dependencies are resolved after all targets are defined.
]]

--[[
    List of targets.
]]
local targets = {}

--[[
    Common table for all rules to "inherit" from.
]]
local common = {
    -- Name of the target
    name = "",

    -- Command line prefix.
    prefix = {},

    -- List of dependencies
    deps = {},

    -- List of source files
    srcs = {},
}

--[[
    Converts the target's name to a usable path. This strips off anything past
    and including a ':'. This is a useful naming convention where multiple
    targets share the same base name but eventually get output to separate
    paths. For example, a shared library "libfoo.so" and a static library
    "libfoo.a" both have "foo" as the name. With this, the rules can be named
    "foo:shared" and "foo:static" to avoid a target name clash.
]]
function common:basename()
    return string.match(self.name, "^[^:]*")
end

--[[
    Adds a target to the table.
]]
function add(target)
    table.insert(targets, target)
    return target
end

--[[
    Resolve dependencies. For all targets, the .rules method is called with the
    set of dependencies.
]]
function resolve()

    local index = {}

    for k,v in ipairs(targets) do
        assert(not index[v.name], "Target name '".. v.name .."' is not unique")
        index[v.name] = v
    end

    -- Resolve dependencies
    for k,v in ipairs(targets) do
        local deps = {}
        for _,dep in ipairs(v.deps) do
            local d = index[dep]
            assert(d, string.format("Dependency '%s' does not exist for target '%s'", dep, v.name))
            table.insert(deps, d)
        end

        -- Replace string dependencies with resolved dependencies.
        v.deps = deps

        v:rules()
    end
end

return {
    common = common,
    add = add,
    resolve = resolve,
}
