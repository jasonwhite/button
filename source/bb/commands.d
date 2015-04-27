/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands;

import bb.node, bb.rule, bb.taskgraph;
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
    import io.range : byBlock;

    TaskGraph graph;

    stderr.println(" :: Reading build description from standard input...");
    graph.addRules(stdin.byBlock!char.parseRules());

    // TODO: Diff build description with database

    stderr.println(" :: Updating...");

    // TODO: Use database to check for changes to resources and tasks.
    auto changedResources = [
            graph.getIndex!Resource("foo.c"),
        ];

    graph.subgraph(changedResources, []).update();

    return 0;
}

/**
 * Generates some input for GraphViz.
 *
 * TODO: Allow the specification of root nodes.
 * TODO: Add --changed option to only show what has changed.
 * TODO: Add --all option to show the whole graph (default).
 */
private int show(string[] args)
{
    import io.range : byBlock;

    TaskGraph graph;

    stderr.println(" :: Reading build description from standard input...");
    graph.addRules(stdin.byBlock!char.parseRules());

    stderr.println(" :: Generating input for GraphViz...");
    graph.show(stdout);

    return 0;
}

/**
 */
private int clean(string[] args)
{
    // TODO

    return 0;
}
