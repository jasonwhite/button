/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates input for GraphViz.
 */
module bb.commands.graph;

import std.array : array;
import std.algorithm.iteration : filter;
import std.getopt;

import io.text,
       io.file;

import bb.vertex,
       bb.graph,
       bb.state,
       bb.build,
       bb.visualize;

private struct Options
{
    // Path to the build description
    string path;

    // Only display the minimal subgraph?
    bool changes;
}

int graph(string[] args)
{
    Options options;

    auto helpInfo = getopt(args,
        "file|f",
            "Path to the build description",
            &options.path,
        "changes|c",
            "Only display the subgraph that will be traversed on an update",
            &options.changes,
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter("Usage: bb graph [--f FILE] [-c]\n", helpInfo.options);
        return 0;
    }

    try
    {
        string path = buildDescriptionPath(options.path);

        auto state = new BuildState(path.stateName);
        auto graph = state.buildGraph;

        if (options.changes)
        {
            // Construct the minimal subgraph based on pending vertices
            auto resourceRoots = state.pending!Resource
                .filter!(v => state.degreeIn(v) == 0)
                .array;

            auto taskRoots = state.pending!Task
                .filter!(v => state.degreeIn(v) == 0)
                .array;

            auto subgraph = graph.subgraph(resourceRoots, taskRoots);
            graph.graphviz(state, stdout);
        }
        else
        {
            graph.graphviz(state, stdout);
        }
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    return 0;
}
