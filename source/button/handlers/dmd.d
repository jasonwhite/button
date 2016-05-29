/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles running "dmd" processes.
 *
 * Inputs and outputs are detected by parsing and modifying the command line
 * before execution. DMD has a "-deps" option for writing inputs to a file. This
 * option is dynamically added to the command line and parsed after the process
 * exits.
 */
module button.handlers.dmd;

import button.log;
import button.resource;

import std.path;
import io.file;

private struct Options
{
    // Flags
    bool compileFlag; // -c
    bool coverageFlag; // -cov
    bool libFlag; // -lib
    bool sharedFlag; // -shared
    bool docFlag; // -D
    bool headerFlag; // -H
    bool mapFlag; // -map
    bool suppressObjectsFlag; // -o-
    bool jsonFlag; // -X
    bool opFlag; // -op

    // Options with arguments
    string outputDir; // -od
    string outputFile; // -of
    string depsFile; // -deps=
    string docDir; // -Dd
    string docFile; // -Df
    string headerDir; // -Hd
    string headerFile; // -Hf
    string[] importDirs; // -I
    string[] stringImportDirs; // -J
    string[] linkerFlags; // -L
    const(string)[] run; // -run
    string jsonFile; // -Xf
    string cmdFile; // @cmdfile

    // Left over files on the command line
    string[] files;

    /**
     * Returns the object file path for the given source file path.
     */
    string objectPath(string sourceFile) const pure
    {
        if (!opFlag)
            sourceFile = baseName(sourceFile);
        return buildPath(outputDir, setExtension(sourceFile, ".o"));
    }

    /**
     * Returns a list of object file paths.
     */
    const(char[])[] objects() const pure
    {
        import std.algorithm.iteration : map, filter;
        import std.algorithm.searching : endsWith;
        import std.array : array;

        if (suppressObjectsFlag)
            return [];

        // If -c is specified, all source files are compiled into separate
        // object files. If -c is not specified, all sources files are compiled
        // into a single object file which is named based on the first source
        // file specified.
        if (compileFlag)
        {
            if (outputFile)
                return [outputFile];
            else
                return files
                    .filter!(p => p.endsWith(".d"))
                    .map!(p => objectPath(p))
                    .array();
        }

        // Object name is based on -of
        if (outputFile)
            return [objectPath(outputFile)];

        auto dSources = files.filter!(p => p.endsWith(".d"));
        if (dSources.empty)
            return [];

        return [objectPath(dSources.front)];
    }

    /**
     * Returns the static library file path.
     */
    string staticLibraryPath() const pure
    {
        import std.algorithm.iteration : filter;
        import std.algorithm.searching : endsWith;

        // If the output file has no extension, ".a" is appended.

        // Note that -op and -o- have no effect when building static libraries.

        string path;

        if (outputFile)
            path = defaultExtension(outputFile, ".a");
        else
        {
            // If no output file is specified with -of, the output file is based on
            // the name of the first source file.
            auto dSources = files.filter!(p => p.endsWith(".d"));
            if (dSources.empty)
                return null;

            path = setExtension(baseName(dSources.front), ".a");
        }

        return buildPath(outputDir, path);
    }

    /**
     * Returns the shared library file path.
     */
    string sharedLibraryPath() const pure
    {
        import std.algorithm.iteration : filter;
        import std.algorithm.searching : endsWith;

        if (outputFile)
            return outputFile;

        // If no output file is specified with -of, the output file is based on
        // the name of the first source file.
        auto dSources = files.filter!(p => p.endsWith(".d"));
        if (dSources.empty)
            return null;

        return setExtension(baseName(dSources.front), ".so");
    }

    /**
     * Returns the static library file path.
     */
    string executablePath() const pure
    {
        import std.algorithm.iteration : filter;
        import std.algorithm.searching : endsWith;

        if (outputFile)
            return outputFile;

        // If no output file is specified with -of, the output file is based on
        // the name of the first source file.
        auto dSources = files.filter!(p => p.endsWith(".d"));
        if (dSources.empty)
            return null;

        return stripExtension(baseName(dSources.front));
    }
}

/**
 * Parses DMD arguments.
 */
private Options parseArgs(const(string)[] args) pure
{
    import std.algorithm.searching : startsWith;
    import std.exception : enforce;
    import std.range : front, popFront, empty;

    Options opts;

    while (!args.empty)
    {
        string arg = args.front;

        if (arg == "-c")
            opts.compileFlag = true;
        else if (arg == "-cov")
            opts.coverageFlag = true;
        else if (arg == "-lib")
            opts.libFlag = true;
        else if (arg == "-shared")
            opts.sharedFlag = true;
        else if (arg == "-lib")
            opts.docFlag = true;
        else if (arg == "-H")
            opts.headerFlag = true;
        else if (arg == "-map")
            opts.mapFlag = true;
        else if (arg == "-X")
            opts.jsonFlag = true;
        else if (arg == "-op")
            opts.opFlag = true;
        else if (arg == "-o-")
            opts.suppressObjectsFlag = true;
        else if (arg == "-run")
        {
            args.popFront();
            opts.run = args;
            break;
        }
        else if (arg.startsWith("-deps="))
            opts.depsFile = arg["-deps=".length .. $];
        else if (arg.startsWith("-od"))
            opts.outputDir = arg["-od".length .. $];
        else if (arg.startsWith("-of"))
            opts.outputFile = arg["-of".length .. $];
        else if (arg.startsWith("-Xf"))
            opts.jsonFile = arg["-Xf".length .. $];
        else if (arg.startsWith("-Dd"))
            opts.docDir = arg["-Dd".length .. $];
        else if (arg.startsWith("-Df"))
            opts.docFile = arg["-Df".length .. $];
        else if (arg.startsWith("-Hd"))
            opts.headerDir = arg["-Hd".length .. $];
        else if (arg.startsWith("-Hf"))
            opts.headerFile = arg["-Hf".length .. $];
        else if (arg.startsWith("-I"))
            opts.importDirs ~= arg["-I".length .. $];
        else if (arg.startsWith("-J"))
            opts.stringImportDirs ~= arg["-J".length .. $];
        else if (arg.startsWith("-L"))
            opts.stringImportDirs ~= arg["-L".length .. $];
        else if (arg.startsWith("@"))
            opts.cmdFile = arg["@".length .. $];
        else if (!arg.startsWith("-"))
            opts.files ~= arg;

        args.popFront();
    }

    return opts;
}

/**
 * Parses the given file for dependencies. Returns a sorted list of inputs.
 */
private void parseInputs(File f, ref Resources inputs)
{
    import io.text : byLine;
    import std.regex : regex, matchAll;

    static r = regex(`\((.*?)\)`);
    foreach (line; f.byLine)
        foreach (c; line.matchAll(r))
            inputs.put(Resource(c[1].idup));
}


int execute(
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        TaskLogger logger
        )
{
    import button.handlers.base : base = execute;

    import std.algorithm.iteration : map, filter, uniq;
    import std.algorithm.searching : endsWith;
    import std.range : enumerate, empty, popFront, front;
    import std.regex : regex, matchAll;
    import std.file : remove;
    import std.array : array;

    import io.text, io.range;

    Options opts = parseArgs(args[1 .. $]);

    string depsPath;

    if (opts.depsFile is null)
    {
        // Output -deps to a temporary file.
        depsPath = tempFile(AutoDelete.no).path;
        args ~= "-deps=" ~ depsPath;
    }
    else
    {
        // -deps= was specified already. Just use this path to get the
        // dependencies.
        depsPath = opts.depsFile;
    }

    // Delete the temporary -deps file when done.
    scope (exit) if (opts.depsFile is null) remove(depsPath);

    auto exitCode = base(args, workDir, inputs, outputs, logger);

    if (exitCode != 0)
    {
        // If the compilation failed, don't bother trying to figure out implicit
        // dependencies. They will be ignored by the build system anyway.
        return exitCode;
    }

    // Add the inputs from the dependency file.
    static r = regex(`\((.*?)\)`);
    foreach (line; File(depsPath).byLine)
        foreach (c; line.matchAll(r))
            inputs.put(c[1]);

    inputs.put(opts.files);

    // Determine the output files based on command line options. If no output
    // file name is specified with -of, the file name is based on the first
    // source file specified on the command line.
    if (opts.libFlag)
    {
        if (auto path = opts.staticLibraryPath())
            outputs.put(path);
    }
    else if (opts.compileFlag)
    {
        outputs.put(opts.objects);
    }
    else if (opts.sharedFlag)
    {
        if (auto path = opts.sharedLibraryPath())
            outputs.put(path);

        outputs.put(opts.objects);
    }
    else
    {
        if (!opts.suppressObjectsFlag)
        {
            // Binary executable.
            if (auto path = opts.executablePath())
                outputs.put(path);

            // Objects
            outputs.put(opts.objects);
        }
    }

    return 0;
}
