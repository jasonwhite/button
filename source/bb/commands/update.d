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
       bb.vertex;

private struct Options
{
    // Path to the build description
    string path;

    // True if this is a dry run.
    bool dryRun;

    // Number of threads to use.
    size_t threads = 0;
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
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(usage, helpInfo.options);
        return 0;
    }

    try
    {
        string path = buildDescriptionPath(options.path);

        auto state = new BuildState(path.stateName);

        {
            // Find changed resources and add them to the set of pending resources.
            state.begin();
            scope (failure) state.rollback();
            scope (success)
            {
                if (!options.dryRun)
                    state.commit();
            }

            syncBuildState(state, path);

            gatherChanges(state);
        }

        update(state, options.threads, options.dryRun);
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: ", e.msg);
        return 1;
    }

    return 0;
}

/**
 * Updates the database with any changes to the build description.
 */
void syncBuildState(BuildState state, string path)
{
    auto r = state[BuildState.buildDescId];
    r.path = path;
    if (r.update())
    {
        println(":: Syncing database with build description...");
        auto build = BuildDescription(path);
        build.sync(state);

        // Analyze the new graph. If any errors are detected, the database rolls
        // back to the previous (good) state.
        println(":: Analyzing graph for errors...");
        BuildStateGraph graph = state.buildGraph();
        graph.checkCycles();
        graph.checkRaces(state);

        // Update the build description resource
        state[BuildState.buildDescId] = r;
    }
}

/**
 * Finds changed resources and marks them as pending in the build state.
 */
void gatherChanges(BuildState state)
{
    println(":: Checking for changes...");

    // TODO: Do this in parallel
    foreach (v; state.indices!Resource)
    {
        if (state.degreeIn(v) != 0)
            continue;

        auto r = state[v];
        if (r.update())
        {
            state[v] = r;
            state.addPending(v);
        }
    }
}

/**
 * Builds pending vertices.
 */
void update(BuildState state, size_t threads, bool dryRun)
{
    import std.array : array;
    import std.algorithm.iteration : filter;

    auto resources = state.pending!Resource.array;
    auto tasks     = state.pending!Task.array;

    if (resources.length == 0 && tasks.length == 0)
    {
        println(":: Nothing to do. Everything is up to date.");
        return;
    }

    // Print what we found.
    printfln(" - Found %d modified resource(s)", resources.length);
    printfln(" - Found %d pending task(s)", tasks.length);

    println(":: Building...");
    auto subgraph = state.buildGraph(resources, tasks);
    subgraph.build(state, threads, dryRun);
}
