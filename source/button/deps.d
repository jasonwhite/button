/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module button.deps;

import button.resource;

/**
 * Format for dependencies received from a task over a pipe.
 */
align(4) struct Dependency
{
    /**
     * Timestamp of the resource. If unknown, this should be set to 0. In such a
     * case, the parent build system will compute the value when needed. This is
     * used by the parent build system to determine if the checksum needs to be
     * recomputed.
     *
     * For files and directories, this is its last modification time.
     */
    ulong timestamp;

    /**
     * SHA-256 checksum of the contents of the resource. If unknown or not
     * computed, this should be set to 0. In such a case, the parent build
     * system will compute the value when needed.
     *
     * For files, this is the checksum of the file contents. For directories,
     * this is the checksum of the paths in the sorted directory listing.
     */
    ubyte[32] checksum;

    /**
     * Length of the name.
     */
    uint length;

    /**
     * Name of the resource that can be used to lookup the data. Length is given
     * by the length member.
     *
     * This is usually a file or directory path. The path does not need to be
     * normalized. The path is assumed to be relative to the associated task's
     * working directory.
     */
    char[0] name;
}

unittest
{
    static assert(Dependency.sizeof == 44);
}

/**
 * Normalizes a dependency path.
 */
private string normalizePath(in char[] workDir, in char[] taskDir, in char[] path) pure
{
    import std.path : isAbsolute, buildNormalizedPath, pathSplitter,
           filenameCmp, dirSeparator;
    import std.algorithm.searching : skipOver;
    import std.algorithm.iteration : joiner;
    import std.array : array;
    import std.utf : byChar;

    auto normalized = buildNormalizedPath(taskDir, path);

    // If the normalized path is absolute, get a relative path if the absolute
    // path is inside the working directory. This is done instead of always
    // getting a relative path because we don't want to get relative paths to
    // directories like "/usr/include". If the build directory moves, absolute
    // paths outside will become invalid.
    if (isAbsolute(normalized) && workDir.length)
    {
        auto normPS = pathSplitter(normalized);
        auto workPS = pathSplitter(workDir);

        alias pred = (a, b) => filenameCmp(a, b) == 0;

        if (skipOver!pred(normPS, &workPS) && workPS.empty)
            return normPS.joiner(dirSeparator).byChar.array;
    }

    return normalized;
}

pure unittest
{
    version (Posix)
    {
        assert(normalizePath("", "", "foo") == "foo");
        assert(normalizePath("", "foo", "bar") == "foo/bar");

        assert(normalizePath("", "foo/../foo/.", "bar/../baz") == "foo/baz");

        assert(normalizePath("", "foo", "/usr/include/bar") == "/usr/include/bar");
        assert(normalizePath("/usr", "foo", "/usr/bar") == "bar");
        assert(normalizePath("/usr/include", "foo", "/usr/bar") == "/usr/bar");
    }
}

/**
 * Range of resources received from a child process.
 */
struct Deps
{
    private
    {
        immutable(void)[] buf;
        const(char)[] taskDir;

        Resource _current;
        bool _empty;

        static string buildDir;
    }

    static this()
    {
        import std.file : getcwd;
        buildDir = getcwd();
    }

    this(immutable(void)[] buf, in char[] taskDir)
    {
        this.buf = buf;
        this.taskDir = taskDir;
        popFront();
    }

    Resource front() inout
    {
        return _current;
    }

    bool empty() const pure nothrow
    {
        return _empty;
    }

    void popFront()
    {
        import std.datetime : SysTime;

        if (buf.length == 0)
        {
            _empty = true;
            return;
        }

        if (buf.length < Dependency.sizeof)
            throw new Exception("Received partial dependency buffer");

        auto dep = *cast(Dependency*)buf[0 .. Dependency.sizeof];

        immutable totalSize = Dependency.sizeof + dep.length;

        string name = cast(string)buf[Dependency.sizeof .. totalSize];

        _current = Resource(
            normalizePath(buildDir, taskDir, name),
            SysTime(cast(long)dep.timestamp),
            dep.checksum
            );

        buf = buf[totalSize .. $];
    }
}

/**
 * Convenience function for returning a range of resources.
 */
Deps deps(immutable(void)[] buf, in char[] taskDir)
{
    return Deps(buf, taskDir);
}
