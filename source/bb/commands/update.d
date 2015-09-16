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
            "Don't make any function changes. Just print what might happen.",
            &options.dryRun,
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
        BuildStateGraph graph;

        {
            state.begin();
            scope (failure) state.rollback();
            scope (success)
            {
                if (!options.dryRun)
                    state.commit();
            }

            // TODO: Only read in the build description if it changes.
            auto build = BuildDescription(path);
            build.sync(state);

            graph = state.buildGraph;
            graph.checkCycles();
            graph.checkRaces(state);

            // Add changed resources to the build state.
            graph.addChangedResources(state);
        }

        // Construct the minimal subgraph based on pending vertices
        auto resources = state.pending!Resource
            .filter!(v => state.degreeIn(v) == 0)
            .array;

        auto tasks = state.pending!Task
            .filter!(v => state.degreeIn(v) == 0)
            .array;

        auto subgraph = graph.subgraph(resources, tasks);
        subgraph.build(state, resources, tasks, options.dryRun);
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: ", e.msg);
        return 1;
    }

    return 0;
}
