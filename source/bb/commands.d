/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands;

import bb.vertex, bb.rule;
import io.text, io.file.stdio;

/**
 * Parses command line options.
 */
int dispatchCommand(string[] args)
{
    // Default to an update
    if (args.length <= 1)
        return update(args);

    auto commandArgs = args[1 .. $];

    switch (args[1])
    {
        case "version":
            return displayVersion(commandArgs);

        case "help":
            return displayHelp(commandArgs);

        case "update":
            return update(commandArgs);

        case "show":
            return show(commandArgs);

        case "clean":
            return clean(commandArgs);

        default:
            displayHelp(commandArgs);
            return 1;
    }
}

/**
 * Display version information.
 */
private int displayVersion(string[] args)
{
    stdout.println("TODO: Display version information here.");
    return 0;
}

/**
 * Display help information.
 */
private int displayHelp(string[] args)
{
    // TODO: Make an argparse library?
    stdout.println("TODO: Display help information here.");
    return 0;
}

/**
 * Updates the build.
 *
 * TODO: Add --dryrun option to simulate an update. This would be useful for
 * refactoring the build description.
 */
private int update(string[] args)
{
    import io.file;
    import io.range : byBlock;
    import bb.state;

    auto buildDesc = (args.length > 1) ? args[1] : "brilliant-build.json";

    try
    {
        auto f = File(buildDesc);
        auto state = new BuildState(buildDesc ~ ".state");

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

/**
 * Generates some input for GraphViz.
 *
 * TODO: Allow the specification of root vertices.
 * TODO: Add --changed option to only show what has changed.
 * TODO: Add --all option to show the whole graph (default).
 */
private int show(string[] args)
{
    import io.range : byBlock;

    // TODO

    return 0;
}

/**
 * Deletes all output resources.
 */
private int clean(string[] args)
{
    // TODO: Find all resources with no incoming edges and delete them.
    // TODO: Investigate if this is a safe thing to do or not.

    return 0;
}
