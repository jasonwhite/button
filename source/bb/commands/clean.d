/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Command to delete outputs.
 */
module bb.commands.clean;

import bb.commands.parsing;

import io.text, io.file.stdio;

import bb.state,
       bb.rule,
       bb.graph,
       bb.build,
       bb.vertex,
       bb.textcolor;

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
