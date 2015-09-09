/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates input for GraphViz.
 */
module bb.commands.graph;

import bb.vertex;
import bb.graph;
import bb.state;
import bb.build;
import bb.visualize;

int graph(string[] args)
{
    import io.text, io.file;
    import io.range : byBlock;

    auto path = (args.length > 1) ? args[1] : "bb.json";

    try
    {
        (new BuildState(path.stateName)).graphviz(stdout);
    }
    catch (ErrnoException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    return 0;
}
