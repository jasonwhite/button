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

import std.parallelism : TaskPool;

import button.log;
import button.resource;
import button.context;
import button.build;
import button.state;
import button.cli;

import darg;

void execute(
        ref BuildContext ctx,
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        TaskLogger logger
        )
{
    import button.handlers.base : base = execute;

    import std.path : dirName, absolutePath, buildPath;

    auto globalOpts = parseArgs!GlobalOptions(args[1 .. $], Config.ignoreUnknown);

    // Not the build command, forward to the base handler.
    if (globalOpts.command != "build")
    {
        base(ctx, args, workDir, inputs, outputs, logger);
        return;
    }

    auto opts = parseArgs!BuildOptions(globalOpts.args);

    string path;

    if (opts.path.length)
        path = buildPath(workDir, opts.path);
    else
        path = buildDescriptionPath(workDir);

    auto state = new BuildState(path.stateName);

    // Reuse as much of the parent build context as possible.
    auto newContext = BuildContext(
            path.dirName.absolutePath,
            ctx.pool, ctx.logger, state,
            ctx.dryRun, ctx.verbose, ctx.color
            );

    state.begin();

    scope (exit)
    {
        if (newContext.dryRun)
            state.rollback();
        else
            state.commit();
    }

    syncBuildState(state, newContext.pool, path);

    // TODO: Get changes from the parent build system because this is
    // duplicating work that has already been done.
    queueChanges(state, newContext.pool, newContext.color);

    // Do the build.
    update(newContext);

    // Publish implicit resources to parent build
    foreach (v; state.enumerate!(Index!Resource))
    {
        immutable degreeIn  = state.degreeIn(v);
        immutable degreeOut = state.degreeOut(v);

        if (degreeIn == 0 && degreeOut == 0)
            continue; // Dangling resource

        if (degreeIn == 0)
            inputs.put(state[v]);
        else
            outputs.put(state[v]);
    }
}

/**
 * Updates the database with any changes to the build description.
 */
private void syncBuildState(BuildState state, TaskPool pool, string path)
{
    auto r = state[BuildState.buildDescId];
    r.path = path;
    if (r.update())
    {
        path.syncState(state, pool);

        // Update the build description resource
        state[BuildState.buildDescId] = r;
    }
}

/**
 * Builds pending vertices.
 */
private void update(ref BuildContext ctx)
{
    import std.array : array;

    import button.task : Task;

    auto resources = ctx.state.pending!Resource.array;
    auto tasks     = ctx.state.pending!Task.array;

    if (resources.length == 0 && tasks.length == 0)
        return;

    ctx.state.buildGraph(resources, tasks).build(ctx);
}
