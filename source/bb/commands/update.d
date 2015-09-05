/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.update;

import bb.vertex;
import bb.graph;
import bb.build;

/**
 * Updates the build.
 *
 * TODO: Add --dryrun option to simulate an update. This would be useful for
 * refactoring the build description.
 */
int update(string[] args)
{
    import io.text, io.file;
    import io.range : byBlock;
    import bb.state;
    import bb.rule;

    auto buildDesc = (args.length > 1) ? args[1] : "bb.json";

    try
    {
        stderr.println(":: Loading build description...");

        auto r = File(buildDesc).byBlock!char;
        auto g = graph(parseRules(&r));

        //auto state = new BuildState(buildDesc.stateName);

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
