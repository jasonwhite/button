/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.update;


/**
 * Updates the build.
 *
 * TODO: Add --dryrun option to simulate an update. This would be useful for
 * refactoring the build description.
 */
int update(string[] args)
{
    import io.text, io.file, io.buffer;
    import io.range : byBlock;
    import std.array : array;
    import std.algorithm.iteration : filter;

    import bb.state, bb.rule, bb.graph, bb.build, bb.vertex, bb.edge;

    // Path to the build description
    auto path = (args.length > 1) ? args[1] : "bb.json";

    try
    {
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

        auto g = state.buildGraph.subgraph(resourceRoots, taskRoots);
    }
    catch (ErrnoException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    stderr.println(":: Done.");

    return 0;
}
