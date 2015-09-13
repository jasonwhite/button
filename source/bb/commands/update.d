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

import io.text,
       io.file;

import bb.state,
       bb.rule,
       bb.graph,
       bb.build,
       bb.vertex;

/**
 * Updates the build.
 *
 * TODO: Add --dryrun option to simulate an update. This would be useful for
 * refactoring the build description.
 */
int update(string[] args)
{
    try
    {
        string path = buildDescriptionPath((args.length > 1) ? args[1] : null);

        stderr.println(":: Loading build description...");

        auto state = new BuildState(path.stateName);
        auto build = BuildDescription(path);
        build.sync(state);

        stderr.println(":: Constructing subgraph...");

        // Construct the minimal subgraph based on pending vertices
        auto resourceRoots = state.pending!Resource
            .filter!(v => state.degreeIn(v) == 0)
            .array;

        auto taskRoots = state.pending!Task
            .filter!(v => state.degreeIn(v) == 0)
            .array;

        // TODO: Check for cycles in the graph.

        auto g = state.buildGraph.subgraph(resourceRoots, taskRoots);
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    return 0;
}
