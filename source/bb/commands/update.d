/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles the 'update' or 'build' command.
 */
module bb.commands.update;

import std.parallelism : TaskPool;

import bb.commands.parsing;

import io.text,
       io.file;

import bb.state,
       bb.rule,
       bb.graph,
       bb.build,
       bb.vertex,
       bb.textcolor,
       bb.log,
       bb.watcher;

/**
 * Returns a build logger based on the command options.
 */
Logger buildLogger(in UpdateOptions opts)
{
    import bb.log.file;
    return new FileLogger(stdout, opts.verbose);
}

/**
 * Updates the build.
 *
 * All outputs are brought up-to-date based on their inputs. If '--autopilot' is
 * specified, once the build finishes, we watch for changes to inputs and run
 * another build.
 */
int updateCommand(UpdateOptions opts, GlobalOptions globalOpts)
{
    import std.parallelism : totalCPUs;

    auto logger = buildLogger(opts);

    if (opts.threads == 0)
        opts.threads = totalCPUs;

    auto pool = new TaskPool(opts.threads - 1);
    scope (exit) pool.finish(true);

    immutable color = TextColor(colorOutput(opts.color));

    string path;
    BuildState state;

    try
    {
        path = buildDescriptionPath(opts.path);
        state = new BuildState(path.stateName);
    }
    catch (BuildException e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Error", color.reset, ": ", e.msg);
        return 1;
    }

    if (!opts.autopilot)
    {
        return doBuild(path, state, opts, pool, logger, color);
    }
    else
    {
        // Do the initial build, checking for changes the old-fashioned way.
        doBuild(path, state, opts, pool, logger, color);

        return doAutoBuild(path, state, opts, pool, logger, color);
    }
}

int doBuild(string path, BuildState state, UpdateOptions opts, TaskPool pool,
        Logger logger, TextColor color)
{
    import std.datetime : StopWatch, AutoStart;

    auto sw = StopWatch(AutoStart.yes);

    scope (exit)
    {
        import std.conv : to;
        import core.time : Duration;
        sw.stop();

        if (opts.verbose)
        {
            println(color.status, ":: Total time taken: ", color.reset,
                    cast(Duration)sw.peek());
        }
    }

    try
    {
        state.begin();
        scope (exit)
        {
            if (opts.dryRun)
                state.rollback();
            else
                state.commit();
        }

        syncBuildState(state, pool, path, opts.verbose, color);

        if (opts.verbose)
            println(color.status, ":: Checking for changes...", color.reset);

        queueChanges(state, pool, color);

        update(state, pool, opts.dryRun, opts.verbose, color, logger);
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

int doAutoBuild(string path, BuildState state, UpdateOptions opts,
        TaskPool pool, Logger logger, TextColor color)
{
    println(color.status, ":: Waiting for changes...", color.reset);

    state.begin();
    scope (exit)
    {
        if (opts.dryRun)
            state.rollback();
        else
            state.commit();
    }

    foreach (changes; ChangeChunks(state, opts.watchDir, opts.delay))
    {
        try
        {
            size_t changed = 0;

            foreach (v; changes)
            {
                // Check if the resource contents actually changed
                auto r = state[v];

                if (r.update())
                {
                    state.addPending(v);
                    state[v] = r;
                    ++changed;
                }
            }

            if (changed > 0)
            {
                syncBuildState(state, pool, path, opts.verbose, color);
                update(state, pool, opts.dryRun, opts.verbose, color, logger);
                println(color.status, ":: Waiting for changes...", color.reset);
            }
        }
        catch (BuildException e)
        {
            stderr.println(color.status, ":: ", color.error,
                    "Error", color.reset, ": ", e.msg);
            continue;
        }
        catch (TaskError e)
        {
            stderr.println(color.status, ":: ", color.error,
                    "Build failed!", color.reset,
                    " See the output above for details.");
            continue;
        }
    }

    //publishResources(state);

    //return 0;
}

/**
 * Updates the database with any changes to the build description.
 */
void syncBuildState(BuildState state, TaskPool pool, string path, bool verbose, TextColor color)
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

        path.syncState(state, pool);

        // Update the build description resource
        state[BuildState.buildDescId] = r;
    }
}

/**
 * Builds pending vertices.
 */
void update(BuildState state, TaskPool pool, bool dryRun, bool verbose,
        TextColor color, Logger logger)
{
    import std.array : array;
    import std.algorithm.iteration : filter;

    auto resources = state.pending!Resource.array;
    auto tasks     = state.pending!Task.array;

    if (resources.length == 0 && tasks.length == 0)
    {
        if (verbose)
        {
            println(color.status, ":: ", color.success,
                    "Nothing to do. Everything is up to date.", color.reset);
        }

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
    subgraph.build(state, pool, dryRun, verbose, color, logger);

    if (verbose)
        println(color.status, ":: ", color.success, "Build succeeded", color.reset);
}
