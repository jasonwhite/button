/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Program entry point.
 */
import bb.commands;

import io.text;

immutable usage = usageString!GlobalOptions("bb");

int main(string[] args)
{
    GlobalOptions opts;

    try
    {
        opts = parseArgs!GlobalOptions(args[1 .. $], Config.ignoreUnknown);
    }
    catch (ArgParseException e)
    {
        println("Error parsing arguments: ", e.msg, "\n");
        println(usage);
        return 1;
    }

    // Rewrite to "help" command.
    if (opts.help == OptionFlag.yes)
    {
        opts.args = (opts.command ? opts.command : "help") ~ opts.args;
        opts.command = "help";
    }

    try
    {
        switch (opts.command)
        {
            case "":
                displayHelp(parseArgs!HelpOptions(opts.args), opts);
                return 1;

            case "help":
                return displayHelp(parseArgs!HelpOptions(opts.args), opts);

            case "version":
                return displayVersion(parseArgs!VersionOptions(opts.args), opts);

            case "build":
            case "update":
                return updateCommand(parseArgs!UpdateOptions(opts.args), opts);

            case "status":
                return statusCommand(parseArgs!StatusOptions(opts.args), opts);

            case "clean":
                return cleanCommand(parseArgs!CleanOptions(opts.args), opts);

            case "gc":
                return collectGarbage(parseArgs!GCOptions(opts.args), opts);

            default:
                printfln("bb: '%s' is not a valid command. See 'bb help'.",
                        opts.command);
                return 1;
        }
    }
    catch (ArgParseException e)
    {
        println("Error parsing arguments: ", e.msg, "\n");
        displayHelp(opts.command);
        return 1;
    }
}
