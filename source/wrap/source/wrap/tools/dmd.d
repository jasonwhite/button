/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module wrap.tools.dmd;

import wrap.pipes;

import io.file;

/**
 * Parses the given file for dependencies. Returns a sorted list of inputs.
 */
immutable(string)[] parseInputs(BufferedFile f)
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
    import std.range : enumerate;
    import std.file : remove;
    import std.array : array;
    import std.regex;

    import io.text, io.range;

    // Check for existing '-deps' options.
    auto deps = args
            .enumerate
            .filter!((x) => x.value.startsWith("-deps"))
            .array;

    if (deps.length > 1)
    {
        stderr.println("Error: Found multiple '-deps' options.");
        return 1;
    }

    auto depsPath = tempFile(AutoDelete.no).path;
    scope (exit) remove(depsPath);

    if (deps.length == 1)
        args[deps[0].index] = "-deps=" ~ depsPath;
    else
        args ~= "-deps=" ~ depsPath;

    auto exitCode = wait(spawnProcess(args));

    foreach (input; BufferedFile(depsPath).parseInputs.uniq)
        sendInput(input);

    return exitCode;
}
