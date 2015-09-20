/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.update;

import std.array : array;
import std.algorithm.iteration : filter;
import std.getopt;

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

        // Read in the build description if it changed.
        auto r = state[BuildState.buildDescId];
        r.path = path;
        if (r.update())
        {
            println(":: Syncing with build description...");

            state.begin();
            scope (failure) state.rollback();
            scope (success)
            {
                if (!options.dryRun)
                    state.commit();
            }

            auto build = BuildDescription(path);
            build.sync(state);

            println(":: Analyzing graph...");
            BuildStateGraph graph = state.buildGraph;
            graph.checkCycles();
            graph.checkRaces(state);

            state[BuildState.buildDescId] = r;
        }

        auto resources = state.indices!Resource
            .filter!(v => state.degreeIn(v) == 0)
            .array;

        auto tasks = state.indices!Task
            .filter!(v => state.degreeIn(v) == 0)
            .array;

        println(":: Generating subgraph...");
        auto subgraph = state.buildGraph(resources, tasks);

        println(":: Building...");
        subgraph.build(state, options.threads, options.dryRun);
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: ", e.msg);
        return 1;
    }

    return 0;
}
