/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Initializes a directory with an initial build description. This is useful
 * to quickly get up and running when creating first creating a build
 * description for the first time on a project.
 *
 * This makes the assumption that you want to use Lua as your build description
 * language and creates an initial BUILD.lua file for you.
 */
module button.commands.init;

import io;

import button.commands.parsing;

/**
 * Contents of .gitignore
 */
immutable gitIgnoreContents = q"EOS
# Generated Button files
.BUILD.lua.json
.*.json.state
EOS";

/**
 * Path to the root build description template.
 */
immutable rootTemplate = "button.json";

/**
 * Contents of the root build description.
 *
 * In general this file should always be a wrapper for generating a build
 * description. Thus, this should never need to be modified by hand.
 *
 * Here, we assume we want to use button-lua to generate the build description.
 */
immutable rootTemplateContents = q"EOS
[
    {
        "inputs": ["BUILD.lua"],
        "task": [["button-lua", "BUILD.lua", "-o", ".BUILD.lua.json"]],
        "outputs": [".BUILD.lua.json"]
    },
    {
        "inputs": [".BUILD.lua.json"],
        "task": [["button", "build", "--color=always", "-f", ".BUILD.lua.json"]],
        "outputs": [".BUILD.lua.json.state"]
    }
]
EOS";

/**
 * Path to the Lua build description template.
 */
immutable luaTemplate = "BUILD.lua";

/**
 * Contents of the BUILD.lua file.
 *
 * TODO: Give more a more useful starting point. This should include:
 *  1. A link to the documentation (when it finally exists).
 *  2. A simple hello world example.
 */
immutable luaTemplateContents = q"EOS
--[[
    This is the top-level build description. This is where you either create
    build rules or delegate to other Lua scripts to create build rules.

    See the documentation for more information on how to get started.
]]

EOS";


int initCommand(InitOptions opts, GlobalOptions globalOpts)
{
    import std.path : buildPath;
    import std.file : FileException, mkdirRecurse;

    try
    {
        // Ensure the directory and its parents exist. This will be used to
        // store the root build description and the build state.
        mkdirRecurse(opts.dir);
    }
    catch (FileException e)
    {
        println(e.msg);
        return 1;
    }

    try
    {
        File(buildPath(opts.dir, ".gitignore"), FileFlags.writeNew)
            .write(gitIgnoreContents);
    }
    catch (SysException e)
    {
        // Don't care if it already exists.
    }

    try
    {
        // Create the root build description
        File(buildPath(opts.dir, rootTemplate), FileFlags.writeNew)
            .write(rootTemplateContents);

        // Create BUILD.lua
        File(buildPath(opts.dir, luaTemplate), FileFlags.writeNew)
            .write(luaTemplateContents);
    }
    catch (SysException e)
    {
        println("Error: ", e.msg);
        println("       Looks like you already ran `button init`.");
        return 1;
    }

    return 0;
}
