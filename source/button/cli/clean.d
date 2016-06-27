/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Command to delete outputs.
 */
module button.cli.clean;

import button.cli.options : CleanOptions, GlobalOptions;

import io.text, io.file.stdio;

import button.state,
       button.rule,
       button.graph,
       button.build,
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
        string statePath = path.stateName;

        auto state = new BuildState(statePath);

        {
            state.begin();
            scope (success)
            {
                if (opts.dryRun)
                    state.rollback();
                else
                    state.commit();
            }

            scope (failure)
                state.rollback();

            clean(state, opts.dryRun);
        }

        // Close the database before (potentially) deleting it.
        state.close();

        if (opts.purge)
        {
            println("Deleting `", statePath, "`");
            remove(statePath);
        }
    }
    catch (BuildException e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Error", color.reset, ": ", e.msg);
        return 1;
    }

    return 0;
}

/**
 * Deletes all outputs from the file system.
 */
void clean(BuildState state, bool dryRun)
{
    import io.text, io.file.stdio;
    import std.range : takeOne;
    import button.resource : Resource;

    foreach (id; state.enumerate!(Index!Resource))
    {
        if (state.degreeIn(id) > 0)
        {
            auto r = state[id];

            println("Deleting `", r, "`");

            r.remove(dryRun);

            // Update the database with the new status of the resource.
            state[id] = r;

            // We want to build this the next time around, so mark its task as
            // pending.
            auto incoming = state
                .incoming!(NeighborIndex!(Index!Resource))(id)
                .takeOne;
            assert(incoming.length == 1,
                    "Output resource has does not have 1 incoming edge! "~
                    "Something has gone horribly wrong!");
            state.addPending(incoming[0].vertex);
        }
    }
}
