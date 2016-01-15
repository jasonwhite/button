/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module bb.deps;

import bb.vertex.resource;

/**
 * Format for dependencies received from a task over a pipe.
 */
struct Dependency
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
     * This is usually a file or directory path. The path do not need to be
     * normalized. If a relative path, the build system assumes it is relative
     * to the working directory that the child was spawned in.
     */
    char[0] name;

    /**
     * Converts the dependency to a Resource.
     */
    T opCast(T : const(Resource))() inout
    {
        import std.exception : assumeUnique;
        import std.datetime : SysTime;
        return Resource(
                assumeUnique(name[0 .. length]),
                SysTime(cast(long)timestamp),
                checksum
                );
    }
}

/**
 * Range of implicit dependencies received from a child process.
 */
auto deps(immutable(void)[] buf)
{
    static struct Deps
    {
        private
        {
            immutable(void)[] buf;
            Dependency dep;
        }

        this(immutable(void)[] buf)
        {
            this.buf = buf;
        }

        const(Dependency) front() const pure
        {
            return dep;
        }

        bool empty() const pure nothrow
        {
            return buf.length == 0;
        }

        void popFront()
        {
            assert(buf.length >= Dependency.sizeof);

            dep = *cast(Dependency*)buf[0 .. Dependency.sizeof];

            buf = buf[Dependency.sizeof + dep.length .. $];
        }
    }

    return Deps(buf);
}
