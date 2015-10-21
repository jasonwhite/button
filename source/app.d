/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
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
            return updateCommand(commandArgs);

        case "graph":
            return graphCommand(commandArgs);

        case "status":
            return statusCommand(commandArgs);

        case "clean":
            return cleanCommand(commandArgs);

        default:
            displayHelp(commandArgs);
            return 1;
    }
}
