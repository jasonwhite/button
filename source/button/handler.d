/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * This is the root command handler. That is, this decides which command handler
 * to use.
 */
module button.handler;

import button.log;
import button.resource;

import button.handlers;

alias Handler = int function(
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        TaskLogger logger
        );

/**
 * Returns a handler appropriate for the given arguments.
 *
 * In general, this simply looks at the base name of the first argument and
 * determines the tool based on that.
 */
Handler selectHandler(const(string)[] args)
{
    import std.path : baseName, filenameCmp;

    if (args.length)
    {
        auto tool = baseName(args[0]);

        if (filenameCmp(tool, "dmd") == 0)
            return &dmd;
    }

    // TODO: Default to the tracer
    return &base;
}

int execute(
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        TaskLogger logger
        )
{
    auto handler = selectHandler(args);

    return handler(args, workDir, inputs, outputs, logger);
}
