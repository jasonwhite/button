/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles running Button recursively.
 *
 * Instead of running another child process, we can use the same process to run
 * Button recursively.
 *
 * There are a several advantages to doing it this way:
 *  - The same thread pool can be reused. Thus, the correct number of worker
 *    threads is always used.
 *  - The same verbosity settings as the parent can be used.
 *  - The same output coloring mode can be used as the parent process.
 *  - Logging of output is more immediate. Output is normally accumulated and
 *    then printed all at once so it isn't interleaved with everything else.
 *  - Avoids the overhead of running another process. However, in general, this
 *    is a non-issue.
 *
 * The only disadvantage to doing it this way is that it is more difficult to
 * implement.
 */
module button.handlers.recursive;

import button.log;
import button.resource;
import button.context;
import button.build;

import button.cli;

import darg;

int execute(
        ref BuildContext ctx,
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        TaskLogger logger
        )
{
    import button.handlers.base : base = execute;

    auto globalOpts = parseArgs!GlobalOptions(args[1 .. $], Config.ignoreUnknown);
    auto buildOpts  = parseArgs!BuildOptions(globalOpts.args);

    // Not the build command, forward to the base handler.
    if (globalOpts.command != "build")
        return base(ctx, args, workDir, inputs, outputs, logger);

    // TODO: Get the build state database and run the build

    return base(ctx, args, workDir, inputs, outputs, logger);
}
