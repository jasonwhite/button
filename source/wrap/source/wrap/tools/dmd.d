/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module wrap.tools.dmd;

import wrap.pipes;

import io.file;

/**
 * Parses the given file for dependencies. Returns a sorted list of inputs.
 */
immutable(string)[] parseInputs(File f)
{
    import io.text : byLine;
    import std.regex;
    import std.array : appender;
    import std.algorithm.sorting : sort;
    import std.exception : assumeUnique;

    auto r = regex(`\((.*?)\)`);

    auto inputs = appender!(string[]);

    foreach (line; f.byLine)
        foreach (c; line.matchAll(r))
            inputs.put(c[1].idup);

    inputs.data.sort();

    return assumeUnique(inputs.data);
}

int dmd(string[] args)
{
    import std.process : wait, spawnProcess;
    import std.algorithm.iteration : filter, uniq;
    import std.algorithm.searching : startsWith;
    import std.range : enumerate, empty;
    import std.file : remove;
    import std.array : array;
    import std.regex;

    import io.text, io.range;

    // Check for existing '-deps' options.
    auto deps = args
            .enumerate
            .filter!(x => x.value.startsWith("-deps="))
            .array;

    if (deps.length > 1)
    {
        stderr.println("Error: Found multiple '-deps' options.");
        return 1;
    }

    string depsPath;

    if (deps.empty)
        depsPath = tempFile(AutoDelete.no).path;
    else
        depsPath = args[deps[0].index]["-deps=".length .. $];

    scope (exit) if (deps.length == 0) remove(depsPath);

    auto exitCode = wait(spawnProcess(args));

    foreach (input; File(depsPath).parseInputs.uniq)
        sendInput(input);

    // Deduce outputs from the command line
    auto outputs = args.filter!(x => x.startsWith("-of")).array;
    if (outputs.length > 1)
    {
        stderr.println("Error: Found multiple '-of' options.");
        return 1;
    }

    if (!outputs.empty)
        sendOutput(outputs[0]["-of".length .. $]);

    return exitCode;
}
