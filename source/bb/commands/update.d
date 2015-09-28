/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.update;

import io.text,
       io.file;

import bb.state,
       bb.rule,
       bb.graph,
       bb.build,
       bb.vertex,
       bb.textcolor;

private struct Options
{
    // Path to the build description
    string path;

    // True if this is a dry run.
    bool dryRun;

    // Number of threads to use.
    size_t threads = 0;

    // When to colorize the output.
    string color = "auto";
}

immutable usage = q"EOS
Usage: bb update [-f FILE]
EOS";

/**
 * Updates the build.
 */
int update(string[] args)
{
    import std.getopt;
    import std.parallelism : totalCPUs;

    Options options;

    auto helpInfo = getopt(args,
        "file|f",
            "Path to the build description",
            &options.path,
        "dryrun|n",
            "Don't make any functional changes. Just print what might happen.",
            &options.dryRun,
        "threads|j",
            "The number of threads to use. Default is the number of logical cores.",
            &options.threads,
        "color",
            "When to colorize the output.",
            &options.color,
    );

    if (options.threads == 0)
        options.threads = totalCPUs;

    auto pool = new TaskPool(options.threads - 1);
    scope (exit) pool.finish(true);

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(usage, helpInfo.options);
        return 0;
    }

    immutable color = TextColor(colorOutput(options.color));

    try
    {
        string path = buildDescriptionPath(options.path);

        auto state = new BuildState(path.stateName);

        {
            state.begin();
            scope (failure) state.rollback();
            scope (success)
            {
                // Note that the transaction is not ended if this is a dry run.
                // We don't want the database to retain changes introduced
                // during the build.
                if (!options.dryRun)
                    state.commit();
            }

            syncBuildState(state, path, color);

            println(":: ", color.status, "Checking for changes...",
                    color.reset);
            gatherChanges(state, pool, color);
        }

        update(state, pool, options.dryRun, color);
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
void syncBuildState(BuildState state, string path, TextColor color)
{
    auto r = state[BuildState.buildDescId];
    r.path = path;
    if (r.update())
    {
        println(color.status, ":: Syncing database with build description...",
                color.reset);
        auto build = BuildDescription(path);
        build.sync(state);

        // Analyze the new graph. If any errors are detected, the database rolls
        // back to the previous (good) state.
        println(color.status, ":: Analyzing graph for errors...", color.reset);
        BuildStateGraph graph = state.buildGraph();
        graph.checkCycles();
        graph.checkRaces(state);

        // Update the build description resource
        state[BuildState.buildDescId] = r;
    }
}

/**
 * Builds pending vertices.
 */
void update(BuildState state, TaskPool pool, bool dryRun, TextColor color)
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
    printfln(" - Found %s%d%s modified resource(s)",
            color.boldBlue, resources.length, color.reset);
    printfln(" - Found %s%d%s pending task(s)",
            color.boldBlue, tasks.length, color.reset);

    println(color.status, ":: Building...", color.reset);
    auto subgraph = state.buildGraph(resources, tasks);
    subgraph.build(state, pool, dryRun, color);

    println(color.status, ":: ", color.success, "Build succeeded", color.reset);
}
