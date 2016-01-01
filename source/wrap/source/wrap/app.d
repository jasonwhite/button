/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Standalone tool that wraps various programs to efficiently capture their
 * inputs and outputs. The lists of inputs and outputs are then sent to the
 * build system, if any.
 *
 * TODO: Add option to override the tool.
 */
module wrap.app;

import std.algorithm : sort;

import wrap.tools;

alias Tool = int function(string[]);

immutable Tool[string] tools;
shared static this()
{
    /**
     * List of tools.
     */
    tools = [
        "dmd": &wrap.tools.dmd.dmd,
    ];
}

version (unittest)
{
    // Dummy main for unit testing.
    void main() {}
}
else
{
    int main(string[] args)
    {
        import std.range : SortedRange;
        import std.stdio;

        if (args.length <= 1)
        {
            stderr.writeln("Usage: bb.wrap program [arg...]");
            return 1;
        }

        if (auto p = args[1] in tools)
        {
            return (*p)(args[1 .. $]);
        }
        else
        {
            // TODO: Fallback to using strace.
            stderr.writeln("Error: Tool not supported.");
            return 1;
        }
    }
}
