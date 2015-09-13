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
}

immutable usage = q"EOS
Usage: bb update [-f FILE]
EOS";

/**
 * Updates the build.
 *
 * TODO: Add --dryrun option to simulate an update. This would be useful for
 * refactoring the build description.
 */
int update(string[] args)
{
    Options options;

    auto helpInfo = getopt(args,
        "file|f",
            "Path to the build description",
            &options.path,
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(usage, helpInfo.options);
        return 0;
    }

    try
    {
        string path = buildDescriptionPath(options.path);

        stderr.println(":: Loading build description...");

        auto state = new BuildState(path.stateName);
        auto build = BuildDescription(path);
        build.sync(state);

        stderr.println(":: Constructing graph...");

        auto graph = state.buildGraph;
        graph.checkCycles();
        graph.checkRaces(state);

        stderr.println(":: Constructing minimal subgraph...");

        // Construct the minimal subgraph based on pending vertices
        auto resourceRoots = state.pending!Resource
            .filter!(v => state.degreeIn(v) == 0)
            .array;

        auto taskRoots = state.pending!Task
            .filter!(v => state.degreeIn(v) == 0)
            .array;

        auto subgraph = graph.subgraph(resourceRoots, taskRoots);
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    return 0;
}
