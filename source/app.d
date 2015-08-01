/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jason White
 *
 * Description:
 * Program entry point.
 */
import bb.commands;

int main(string[] args)
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

        default:
            displayHelp(commandArgs);
            return 1;
    }
}
