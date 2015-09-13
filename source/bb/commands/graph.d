/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates input for GraphViz.
 */
module bb.commands.graph;

import io.text,
       io.file;

import bb.vertex,
       bb.graph,
       bb.state,
       bb.build,
       bb.visualize;

int graph(string[] args)
{
    try
    {
        string path = buildDescriptionPath((args.length > 1) ? args[1] : null);

        auto state = new BuildState(path.stateName);
        state.buildGraph.graphviz(state, stdout);
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    return 0;
}
