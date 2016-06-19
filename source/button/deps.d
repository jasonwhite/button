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
 * Range of resources received from a child process.
 */
struct Deps
{
    private
    {
        immutable(void)[] buf;

        Resource _current;
        bool _empty;
    }

    this(immutable(void)[] buf)
    {
        this.buf = buf;
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
            name,
            SysTime(cast(long)dep.timestamp),
            dep.checksum
            );

        buf = buf[totalSize .. $];
    }
}

/**
 * Convenience function for returning a range of resources.
 */
Deps deps(immutable(void)[] buf)
{
    return Deps(buf);
}
