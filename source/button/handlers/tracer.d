/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * The tracer traces system calls to determine inputs and outputs. For now, it
 * just runs the command with strace and parses the output. It would be better
 * to use ptrace directly, but the ptrace API is the stuff of nightmares.
 */
module button.handlers.tracer;

import button.log;
import button.resource;

import io.file;

version (Posix)
{

private struct Trace
{
    private
    {
        import std.regex : regex;

        static re_open   = regex(`open\("([^"]*)", ([^,)]*)`);
        static re_creat  = regex(`creat\("([^"]*)",`);
        static re_rename = regex(`rename\("([^"]*)", "([^"]*)"\)`);
        static re_mkdir  = regex(`mkdir\("([^"]*)", (0[0-7]*)\)`);
        static re_chdir  = regex(`chdir\("([^"]*)"\)`);
    }

    /**
     * Paths that start with these fragments are ignored.
     */
    private static immutable ignoredPaths = [
        "/dev/",
        "/etc/",
        "/proc/",
        "/tmp/",
        "/usr/",
    ];

    /**
     * Returns: True if the given path should be ignored, false otherwise.
     */
    private static bool ignorePath(const(char)[] path) pure nothrow
    {
        import std.algorithm.searching : startsWith;

        foreach (ignored; ignoredPaths)
        {
            if (path.startsWith(ignored))
                return true;
        }

        return false;
    }

    private
    {
        import std.container.rbtree;

        // Current working directories of each tracked process.
        string[int] processes;

        RedBlackTree!string inputs, outputs;
    }

    void dump(ref Resources implicitInputs, ref Resources implicitOutputs)
    {
        implicitInputs.put(inputs[]);
        implicitOutputs.put(outputs[]);
    }

    string filePath(int pid, const(char)[] path)
    {
        import std.path : buildNormalizedPath;

        if (auto p = pid in processes)
            return buildNormalizedPath(*p, path);

        return buildNormalizedPath(path);
    }

    void parse(File f)
    {
        import io.text;
        import std.conv : parse, ConvException;
        import std.string : munch;
        import std.algorithm.searching : startsWith;
        import std.regex : matchFirst;

        inputs = redBlackTree!string();
        outputs = redBlackTree!string();

        foreach (line; f.byLine)
        {
            int pid;

            try
                pid = line.parse!int();
            catch (ConvException e)
                continue;

            line.munch(" \t");

            if (line.startsWith("open"))
            {
                auto captures = line.matchFirst(re_open);
                if (captures.empty)
                    continue;

                open(pid, captures[1], captures[2]);
            }
            else if (line.startsWith("creat"))
            {
                auto captures = line.matchFirst(re_open);
                if (captures.empty)
                    continue;

                creat(pid, captures[1]);
            }
            else if (line.startsWith("rename"))
            {
                auto captures = line.matchFirst(re_rename);
                if (captures.empty)
                    continue;

                rename(pid, captures[1], captures[2]);
            }
            else if (line.startsWith("mkdir"))
            {
                auto captures = line.matchFirst(re_mkdir);
                if (captures.empty)
                    continue;

                mkdir(pid, captures[1]);
            }
            else if (line.startsWith("chdir"))
            {
                auto captures = line.matchFirst(re_chdir);
                if (captures.empty)
                    continue;

                chdir(pid, captures[1]);
            }
        }
    }

    void open(int pid, const(char)[] path, const(char)[] flags)
    {
        import std.algorithm.iteration : splitter;

        if (ignorePath(path))
            return;

        foreach (flag; splitter(flags, '|'))
        {
            if (flag == "O_WRONLY" || flag == "O_RDWR")
            {
                // Opened in write mode. It's an output even if it was read
                // before.
                auto f = filePath(pid, path);
                inputs.removeKey(f);
                outputs.insert(f);
                break;
            }
            else if (flag == "O_RDONLY")
            {
                // Opened in read-only mode. It's an input unless it's already
                // an output. Consider the scenario of writing a new file and
                // then reading it back in. In such cases, the file should only
                // be considered an output.
                auto f = filePath(pid, path);
                if (f !in outputs)
                    inputs.insert(f);
                break;
            }
        }
    }

    void creat(int pid, const(char)[] path)
    {
        if (ignorePath(path))
            return;

        outputs.insert(filePath(pid, path));
    }

    void rename(int pid, const(char)[] from, const(char)[] to)
    {
        if (ignorePath(to))
            return;

        auto output = filePath(pid, to);
        outputs.removeKey(filePath(pid, from));
        inputs.removeKey(output);
        outputs.insert(output);
    }

    void mkdir(int pid, const(char)[] dir)
    {
        outputs.insert(filePath(pid, dir));
    }

    void chdir(int pid, const(char)[] path)
    {
        processes[pid] = path.idup;
    }
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

    import std.file : remove;

    auto traceLog = tempFile(AutoDelete.no).path;
    scope (exit) remove(traceLog);

    auto traceArgs = [
        "strace",

        // Follow child processes
        "-f",

        // Output to a file to avoid mixing the child's output
        "-o", traceLog,

        // Only trace the sys calls we are interested in
        "-e", "trace=open,creat,rename,mkdir,chdir",
        ] ~ args;

    auto exitCode = base(traceArgs, workDir, inputs, outputs, logger);

    if (exitCode != 0)
    {
        // If the command failed, don't bother trying to figure out implicit
        // dependencies. They will be ignored by the build system anyway.
        return exitCode;
    }

    // Parse the trace log to determine dependencies
    auto strace = Trace();
    strace.parse(File(traceLog));
    strace.dump(inputs, outputs);

    return 0;
}

}
