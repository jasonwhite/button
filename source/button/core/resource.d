/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module button.core.resource;
import std.digest.digest : DigestType, isDigest;

import std.array : Appender;

/**
 * A resource identifier.
 */
alias ResourceId = string;

/**
 * A resource key must be unique.
 */
struct ResourceKey
{
    /**
     * File path to the resource. To ensure uniqueness, this should never be
     * changed after construction.
     */
    string path;

    /**
     * Compares this key with another.
     */
    int opCmp()(const auto ref typeof(this) that) const pure nothrow
    {
        import std.algorithm.comparison : cmp;
        return cmp(this.path, that.path);
    }
}

unittest
{
    static assert(ResourceKey("abc") == ResourceKey("abc"));
    static assert(ResourceKey("abc") < ResourceKey("abcd"));
}

/**
 * Compute the checksum of a file.
 */
private DigestType!Hash digestFile(Hash)(string path)
    if (isDigest!Hash)
{
    import std.digest.digest : digest;
    import io.file : SysException, File, FileFlags;
    import io.range : byChunk;

    ubyte[4096] buf;

    try
    {
        return digest!Hash(File(path, FileFlags.readExisting).byChunk(buf));
    }
    catch (SysException e)
    {
        // This may fail if the given path is a directory. The path could have
        // also been deleted.
        return typeof(return).init;
    }
}

/**
 * A representation of a file on the disk.
 *
 * TODO: Support directories as well as files.
 */
struct Resource
{
    import std.datetime : SysTime;
    import std.digest.digest : DigestType;
    import std.digest.sha : SHA256;

    /**
     * Digest to use to determine changes.
     */
    alias Digest = SHA256;

    enum Status
    {
        unknown  = SysTime.max,
        notFound = SysTime.min,
    }

    /**
     * File path to the resource. To ensure uniqueness, this should never be
     * changed after construction.
     */
    ResourceId path;

    /**
     * Last time the file was modified.
     */
    SysTime lastModified = Status.unknown;

    /**
     * Checksum of the file.
     *
     * TODO: If this is a directory, checksum the sorted list of its contents.
     */
    DigestType!Digest checksum;

    this(ResourceId path, SysTime lastModified = Status.unknown,
            const(ubyte[]) checksum = []) pure
    {
        import std.algorithm.comparison : min;

        this.path = path;
        this.lastModified = lastModified;

        // The only times the length will be different are:
        //  - The database is corrupt
        //  - The digest length changed
        // In either case, it doesn't matter. If the checksum changes it will
        // simply be recomputed and order will once again be restored in the
        // realm.
        immutable bytes = min(this.checksum.length, checksum.length);
        this.checksum[0 .. bytes] = checksum[0 .. bytes];
    }

    /**
     * Returns a string representation of this resource. This is just the path
     * to the resource.
     */
    string toString() const pure nothrow
    {
        return path;
    }

    /**
     * Returns a short string representation of the path.
     */
    @property string toShortString() const pure nothrow
    {
        import std.path : baseName;
        return path.baseName;
    }

    /**
     * Returns the unique identifier for this vertex.
     */
    @property inout(ResourceId) identifier() inout pure nothrow
    {
        return path;
    }

    /**
     * Compares the file path of this resource with another.
     */
    int opCmp()(const auto ref Resource rhs) const pure
    {
        import std.path : filenameCmp;
        return filenameCmp(this.path, rhs.path);
    }

    /// Ditto
    bool opEquals()(const auto ref Resource rhs) const pure
    {
        return opCmp(rhs) == 0;
    }

    unittest
    {
        assert(Resource("a") < Resource("b"));
        assert(Resource("b") > Resource("a"));

        assert(Resource("test", SysTime(1)) == Resource("test", SysTime(1)));
        assert(Resource("test", SysTime(1)) == Resource("test", SysTime(2)));
    }

    /**
     * Updates the last modified time and checksum of this resource. Returns
     * true if anything changed.
     *
     * Note that the checksum is not recomputed if the modification time is the
     * same.
     */
    bool update()
    {
        import std.file : timeLastModified, FileException;

        immutable lastModified = timeLastModified(path, Status.notFound);

        if (lastModified != this.lastModified)
        {
            import std.digest.md;
            this.lastModified = lastModified;

            if (lastModified != Status.notFound)
            {
                auto checksum = digestFile!Digest(path);
                if (checksum != this.checksum)
                {
                    this.checksum = checksum;
                    return true;
                }

                // Checksum didn't change.
                return false;
            }

            return true;
        }

        return false;
    }

    /**
     * Returns true if the status of this resource is known.
     */
    @property bool statusKnown() const pure nothrow
    {
        return lastModified != Status.unknown;
    }

    /**
     * Deletes the resource from disk.
     */
    void remove(bool dryRun) nothrow
    {
        import std.file : unlink = remove, isFile;
        import io;

        // Only delete this file if we know about it. This helps prevent the
        // build system from haphazardly deleting files that were added to the
        // build description but never output by a task.
        if (!statusKnown)
            return;

        // TODO: Use rmdir instead if this is a directory.

        if (!dryRun)
        {
            try
            {
                unlink(path);
            }
            catch (Exception e)
            {
            }
        }

        lastModified = Status.notFound;
    }
}

/**
 * Normalizes a resource path while trying to make it relative to the buildRoot.
 * If it cannot be done, the path is made absolute.
 *
 * Params:
 *     buildRoot = The root directory of the build. Probably always the current
 *                 working directory.
 *     taskDir   = The working directory of the task this is for. The path is
 *                 normalized relative to this directory.
 *     path      = The path to be normalized.
 */
string normPath(const(char)[] buildRoot, const(char)[] taskDir,
        const(char)[] path) pure
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
    if (isAbsolute(normalized) && buildRoot.length)
    {
        auto normPS  = pathSplitter(normalized);
        auto buildPS = pathSplitter(buildRoot);

        alias pred = (a, b) => filenameCmp(a, b) == 0;

        if (skipOver!pred(normPS, &buildPS) && buildPS.empty)
            return normPS.joiner(dirSeparator).byChar.array;
    }

    return normalized;
}

pure unittest
{
    version (Posix)
    {
        assert(normPath("", "", "foo") == "foo");
        assert(normPath("", "foo", "bar") == "foo/bar");

        assert(normPath("", "foo/../foo/.", "bar/../baz") == "foo/baz");

        assert(normPath("", "foo", "/usr/include/bar") == "/usr/include/bar");
        assert(normPath("/usr", "foo", "/usr/bar") == "bar");
        assert(normPath("/usr/include", "foo", "/usr/bar") == "/usr/bar");
    }
}

/**
 * Output range of implicit resources.
 *
 * This is used to easily accumulate implicit resources while also normalizing
 * their paths at the same time.
 */
struct Resources
{
    import std.array : Appender;
    import std.range : isInputRange, ElementType;

    Appender!(Resource[]) resources;

    alias resources this;

    string buildDir;
    string taskDir;

    this(string buildDir, string taskDir)
    {
        this.buildDir = buildDir;
        this.taskDir = taskDir;
    }

    void put(R)(R items)
        if (isInputRange!R && is(ElementType!R : const(char)[]))
    {
        import std.range : empty, popFront, front;

        for (; !items.empty; items.popFront())
            put(items.front);
    }

    void put(const(char)[] item)
    {
        resources.put(Resource(normPath(buildDir, taskDir, item)));
    }

    void put(R)(R items)
        if (isInputRange!R && is(ElementType!R : Resource))
    {
        resources.put(items);
    }

    void put(Resource item)
    {
        item.path = normPath(buildDir, taskDir, item.path);
        resources.put(item);
    }
}
