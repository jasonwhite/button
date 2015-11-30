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
                displayHelp(parseOpts!"help"(opts.args), opts);
                return 1;

            case "help":
                return displayHelp(parseOpts!"help"(opts.args), opts);

            case "build":
            case "update":
                return updateCommand(parseOpts!"update"(opts.args), opts);

            case "status":
                return statusCommand(parseOpts!"status"(opts.args), opts);

            case "clean":
                return cleanCommand(parseOpts!"clean"(opts.args), opts);

            case "gc":
                return collectGarbage(parseOpts!"gc"(opts.args), opts);

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
