/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.help;

import io.text, io.file.stdio;

/**
 * Display version information.
 */
int displayVersion(string[] args)
{
    stdout.println("bb version 0.1.0");
    return 0;
}

/**
 * Display help information.
 */
int displayHelp(string[] args)
{
    if (args.length == 1)
    {
        displayUsage();
        return 0;
    }

    return 0;
}

immutable string usageHelp = q"EOS
Usage: bb <command> {options] [<args>]

The most commonly used commands are:
   update   Builds based on changes.
   graph    Writes the build description in GraphViz format.
   help     Prints help on a specific command.

Use 'bb help <command>' to get help on a specific command.
EOS";

/**
 * Display usage information.
 */
int displayUsage()
{
    print(usageHelp);
    return 1;
}
