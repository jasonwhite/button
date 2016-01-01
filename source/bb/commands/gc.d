/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.gc;

import bb.commands.parsing;

import io.text, io.file.stdio;

import bb.state,
       bb.rule,
       bb.graph,
       bb.build,
       bb.vertex,
       bb.textcolor;

/**
 * Collects garbage.
 */
int collectGarbage(GCOptions opts, GlobalOptions globalOpts)
{
    import std.getopt;

    immutable color = TextColor(colorOutput(opts.color));

    try
    {
        string path = buildDescriptionPath(opts.path);

        auto state = new BuildState(path.stateName);
    }
    catch (BuildException e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Error", color.reset, ": ", e.msg);
        return 1;
    }

    return 0;
}
