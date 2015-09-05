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

int graph(string[] args)
{
    import io.text, io.file;
    import io.range : byBlock;
    import bb.rule;

    auto buildDesc = (args.length > 1) ? args[1] : "bb.json";

    try
    {
        stderr.println(":: Loading build description...");
        auto r = File(buildDesc).byBlock!char;
        auto g = graph(parseRules(&r));
        g.graphviz(stdout);
    }
    catch (ErrnoException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    return 0;
}
