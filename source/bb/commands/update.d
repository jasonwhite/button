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

    import bb.state, bb.rule, bb.graph, bb.build, bb.vertex, bb.edge;

    // Path to the build description
    auto path = (args.length > 1) ? args[1] : "bb.json";

    try
    {
        stderr.println(":: Loading build description...");

        auto state = new BuildState(path.stateName);
        auto build = BuildDescription(path);
        build.sync(state);

        // The minimal subgraph can now be constructed

        // TODO: Diff build description with database
        stderr.println(":: Checking for build description changes...");
    }
    catch (ErrnoException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    stderr.println(":: Updating...");

    // TODO: Build subgraph and update.

    return 0;
}
