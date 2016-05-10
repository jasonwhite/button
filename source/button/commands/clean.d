/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Command to delete outputs.
 */
module button.commands.clean;

import button.commands.parsing;

import io.text, io.file.stdio;

import button.state,
       button.rule,
       button.graph,
       button.build,
       button.vertex,
       button.textcolor;

/**
 * Deletes outputs.
 */
int cleanCommand(CleanOptions opts, GlobalOptions globalOpts)
{
    import std.getopt;
    import std.file : remove;

    immutable color = TextColor(colorOutput(opts.color));

    try
    {
        string path = buildDescriptionPath(opts.path);

        auto state = new BuildState(path.stateName);
        clean(state);

        if (opts.purge)
            remove(path.stateName);
    }
    catch (BuildException e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Error", color.reset, ": ", e.msg);
        return 1;
    }

    return 0;
}
