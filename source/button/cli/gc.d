/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module button.cli.gc;

import button.cli.options : GCOptions, GlobalOptions;

import io.text, io.file.stdio;

import button.state,
       button.rule,
       button.graph,
       button.build,
       button.textcolor;

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
