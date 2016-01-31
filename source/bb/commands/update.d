/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.update;

import bb.commands.parsing;

import io.text,
       io.file;

import bb.state,
       bb.rule,
       bb.graph,
       bb.build,
       bb.vertex,
       bb.textcolor;

/**
 * Updates the build.
 */
int updateCommand(UpdateOptions opts, GlobalOptions globalOpts)
{
    import std.parallelism : totalCPUs;
    import std.datetime : StopWatch;

    immutable bool dryRun  = opts.dryRun == OptionFlag.yes;
    immutable bool verbose = opts.verbose == OptionFlag.yes;

    StopWatch sw;

    if (opts.threads == 0)
        opts.threads = totalCPUs;

    immutable color = TextColor(colorOutput(opts.color));

    sw.start();

    scope (exit)
    {
        import std.conv : to;
        import core.time : Duration;
        sw.stop();
        println(color.status, ":: Total time taken: ", color.reset,
                cast(Duration)sw.peek());
    }

    auto pool = new TaskPool(opts.threads - 1);
    scope (exit) pool.finish(true);

    try
    {
        string path = buildDescriptionPath(opts.path);

        auto state = new BuildState(path.stateName);

        {
            state.begin();
            scope (failure) state.rollback();
            scope (success)
            {
                // Note that the transaction is not ended if this is a dry run.
                // We don't want the database to retain changes introduced
                // during the build.
                if (!dryRun)
                    state.commit();
            }

            syncBuildState(state, path, verbose, color);

            if (verbose)
                println(color.status, ":: Checking for changes...", color.reset);

            queueChanges(state, pool, color);
        }

        update(state, pool, dryRun, verbose, color);

        publishResources(state);
    }
    catch (BuildException e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Error", color.reset, ": ", e.msg);
        return 1;
    }
    catch (TaskError e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Build failed!", color.reset,
                " See the output above for details.");
        return 1;
    }

    return 0;
}

/**
 * Updates the database with any changes to the build description.
 */
void syncBuildState(BuildState state, string path, bool verbose, TextColor color)
{
    // TODO: Don't store the build description in the database. The parent build
    // system should store the change state of the build description and tell
    // the child which input resources have changed upon an update.
    auto r = state[BuildState.buildDescId];
    r.path = path;
    if (r.update())
    {
        if (verbose)
            println(color.status, ":: Build description changed. Syncing with the database...",
                    color.reset);

        path.syncState(state);

        // Update the build description resource
        state[BuildState.buildDescId] = r;
    }
}

/**
 * Builds pending vertices.
 */
void update(BuildState state, TaskPool pool, bool dryRun, bool verbose,
        TextColor color)
{
    import std.array : array;
    import std.algorithm.iteration : filter;

    auto resources = state.pending!Resource.array;
    auto tasks     = state.pending!Task.array;

    if (resources.length == 0 && tasks.length == 0)
    {
        println(color.status, ":: ", color.success,
                "Nothing to do. Everything is up to date.", color.reset);
        return;
    }

    // Print what we found.
    if (verbose)
    {
        printfln(" - Found %s%d%s modified resource(s)",
                color.boldBlue, resources.length, color.reset);
        printfln(" - Found %s%d%s pending task(s)",
                color.boldBlue, tasks.length, color.reset);

        println(color.status, ":: Building...", color.reset);
    }

    auto subgraph = state.buildGraph(resources, tasks);
    subgraph.build(state, pool, dryRun, verbose, color);

    println(color.status, ":: ", color.success, "Build succeeded", color.reset);
}
