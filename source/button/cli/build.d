/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles the 'build' command.
 */
module button.cli.build;

import std.parallelism : TaskPool;

import button.cli.options : BuildOptions, GlobalOptions;

import io.text, io.file;

import button.state;
import button.rule;
import button.graph;
import button.build;
import button.resource;
import button.task;
import button.textcolor;
import button.log;
import button.watcher;
import button.context;

/**
 * Returns a build logger based on the command options.
 */
Logger buildLogger(in BuildOptions opts)
{
    import button.log.file;
    return new FileLogger(stdout, opts.verbose);
}

/**
 * Updates the build.
 *
 * All outputs are brought up-to-date based on their inputs. If '--autopilot' is
 * specified, once the build finishes, we watch for changes to inputs and run
 * another build.
 */
int buildCommand(BuildOptions opts, GlobalOptions globalOpts)
{
    import std.parallelism : totalCPUs;
    import std.path : dirName, absolutePath;

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

    auto context = BuildContext(absolutePath(dirName(path)), pool, logger,
            state, opts.dryRun, opts.verbose, color);

    if (!opts.autopilot)
    {
        return doBuild(context, path);
    }
    else
    {
        // Do the initial build, checking for changes the old-fashioned way.
        doBuild(context, path);

        return doAutoBuild(context, path, opts.watchDir, opts.delay);
    }
}

int doBuild(ref BuildContext ctx, string path)
{
    import std.datetime : StopWatch, AutoStart;

    auto sw = StopWatch(AutoStart.yes);

    scope (exit)
    {
        import std.conv : to;
        import core.time : Duration;
        sw.stop();

        if (ctx.verbose)
        {
            println(ctx.color.status, ":: Total time taken: ", ctx.color.reset,
                    cast(Duration)sw.peek());
        }
    }

    try
    {
        ctx.state.begin();
        scope (exit)
        {
            if (ctx.dryRun)
                ctx.state.rollback();
            else
                ctx.state.commit();
        }

        syncBuildState(ctx, path);

        if (ctx.verbose)
            println(ctx.color.status, ":: Checking for changes...", ctx.color.reset);

        queueChanges(ctx.state, ctx.pool, ctx.color);

        update(ctx);
    }
    catch (BuildException e)
    {
        stderr.println(ctx.color.status, ":: ", ctx.color.error,
                "Error", ctx.color.reset, ": ", e.msg);
        return 1;
    }
    catch (Exception e)
    {
        stderr.println(ctx.color.status, ":: ", ctx.color.error,
                "Build failed!", ctx.color.reset,
                " See the output above for details.");
        return 1;
    }

    return 0;
}

int doAutoBuild(ref BuildContext ctx, string path,
        string watchDir, size_t delay)
{
    println(ctx.color.status, ":: Waiting for changes...", ctx.color.reset);

    ctx.state.begin();
    scope (exit)
    {
        if (ctx.dryRun)
            ctx.state.rollback();
        else
            ctx.state.commit();
    }

    foreach (changes; ChangeChunks(ctx.state, watchDir, delay))
    {
        try
        {
            size_t changed = 0;

            foreach (v; changes)
            {
                // Check if the resource contents actually changed
                auto r = ctx.state[v];

                if (r.update())
                {
                    ctx.state.addPending(v);
                    ctx.state[v] = r;
                    ++changed;
                }
            }

            if (changed > 0)
            {
                syncBuildState(ctx, path);
                update(ctx);
                println(ctx.color.status, ":: Waiting for changes...", ctx.color.reset);
            }
        }
        catch (BuildException e)
        {
            stderr.println(ctx.color.status, ":: ", ctx.color.error,
                    "Error", ctx.color.reset, ": ", e.msg);
            continue;
        }
        catch (TaskError e)
        {
            stderr.println(ctx.color.status, ":: ", ctx.color.error,
                    "Build failed!", ctx.color.reset,
                    " See the output above for details.");
            continue;
        }
    }

    // Unreachable
}

/**
 * Updates the database with any changes to the build description.
 */
void syncBuildState(ref BuildContext ctx, string path)
{
    // TODO: Don't store the build description in the database. The parent build
    // system should store the change state of the build description and tell
    // the child which input resources have changed upon an update.
    auto r = ctx.state[BuildState.buildDescId];
    r.path = path;
    if (r.update())
    {
        if (ctx.verbose)
            println(ctx.color.status,
                    ":: Build description changed. Syncing with the database...",
                    ctx.color.reset);

        path.syncState(ctx.state, ctx.pool);

        // Update the build description resource
        ctx.state[BuildState.buildDescId] = r;
    }
}

/**
 * Builds pending vertices.
 */
void update(ref BuildContext ctx)
{
    import std.array : array;
    import std.algorithm.iteration : filter;

    auto resources = ctx.state.pending!Resource.array;
    auto tasks     = ctx.state.pending!Task.array;

    if (resources.length == 0 && tasks.length == 0)
    {
        if (ctx.verbose)
        {
            println(ctx.color.status, ":: ", ctx.color.success,
                    "Nothing to do. Everything is up to date.", ctx.color.reset);
        }

        return;
    }

    // Print what we found.
    if (ctx.verbose)
    {
        printfln(" - Found %s%d%s modified resource(s)",
                ctx.color.boldBlue, resources.length, ctx.color.reset);
        printfln(" - Found %s%d%s pending task(s)",
                ctx.color.boldBlue, tasks.length, ctx.color.reset);

        println(ctx.color.status, ":: Building...", ctx.color.reset);
    }

    auto subgraph = ctx.state.buildGraph(resources, tasks);
    subgraph.build(ctx);

    if (ctx.verbose)
        println(ctx.color.status, ":: ", ctx.color.success, "Build succeeded",
                ctx.color.reset);
}
