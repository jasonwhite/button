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
    if (args.length <= 1)
        return displayUsage();

    auto commandArgs = args[1 .. $];

    switch (args[1])
    {
        case "--version":
        case "version":
            return displayVersion(commandArgs);

        case "--help":
        case "help":
            return displayHelp(commandArgs);

        case "build":
        case "update":
            return update(commandArgs);

        case "graph":
            return graph(commandArgs);

        case "status":
            return status(commandArgs);

        default:
            displayHelp(commandArgs);
            return 1;
    }
}
