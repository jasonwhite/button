/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module button.resource;
import std.digest : DigestType, isDigest;

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
    import std.digest : digest;
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
 * Computes a stable checksum for the given directory.
 *
 * Note that we cannot use std.file.dirEntries here. dirEntries() yields the
 * full path to the directory entries. We only want the file name, not the path
 * to it. Thus, we're forced to list the directory contents the old fashioned
 * way.
 */
version (Posix)
private DigestType!Hash digestDir(Hash)(const(char)* path)
    if (isDigest!Hash)
{
    import core.stdc.string : strlen;
    import std.array : Appender;
    import std.algorithm.sorting : sort;
    import core.sys.posix.dirent : DIR, dirent, opendir, closedir, readdir;

    Appender!(string[]) entries;

    if (DIR* dir = opendir(path))
    {
        scope (exit) closedir(dir);

        while (true)
        {
            dirent* entry = readdir(dir);
            if (!entry) break;

            entries.put(entry.d_name[0 .. strlen(entry.d_name.ptr)].idup);
        }
    }
    else
    {
        // In this case, this is either not a directory or it doesn't exist.
        return typeof(return).init;
    }

    // The order in which files are listed is not guaranteed to be sorted.
    // Whether or not it is sorted depends on the file system implementation.
    // Thus, we sort them to eliminate that potential source of non-determinism.
    sort(entries.data);

    Hash digest;
    digest.start();

    foreach (name; entries.data)
    {
        digest.put(cast(const(ubyte)[])name);
        digest.put(cast(ubyte)0); // Null terminator
    }

    return digest.finish();
}

/**
 * Computes a stable checksum for the given directory.
 */
private DigestType!Hash digestDir(Hash)(string path)
    if (isDigest!Hash)
{
    import std.internal.cstring : tempCString;

    return digestDir!Hash(path.tempCString());
}

/**
 * A representation of a file on the disk.
 */
struct Resource
{
    import std.datetime : SysTime;
    import std.digest.sha : SHA256;

    /**
     * Digest to use to determine changes.
     */
    alias Hash = SHA256;

    enum Status
    {
        // The state of the resource is not known.
        unknown,

        // The path does not exist on disk.
        missing,

        // The path refers to a file.
        file,

        // The path refers to a directory.
        directory,
    }

    /**
     * File path to the resource. To ensure uniqueness, this should never be
     * changed after construction.
     */
    ResourceId path;

    /**
     * Status of the file.
     */
    Status status = Status.unknown;

    /**
     * Checksum of the file.
     */
    DigestType!Hash checksum;

    this(ResourceId path, Status status = Status.unknown,
            const(ubyte[]) checksum = []) pure
    {
        import std.algorithm.comparison : min;

        this.path = path;
        this.status = status;

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

        assert(Resource("test", Resource.Status.unknown) ==
               Resource("test", Resource.Status.unknown));
        assert(Resource("test", Resource.Status.file) ==
               Resource("test", Resource.Status.directory));
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
        version (Posix)
        {
            import core.sys.posix.sys.stat : lstat, stat_t, S_IFMT, S_IFDIR,
                   S_IFREG;
            import io.file.stream : SysException;
            import core.stdc.errno : errno, ENOENT;
            import std.datetime : unixTimeToStdTime;
            import std.internal.cstring : tempCString;

            stat_t statbuf = void;

            auto tmpPath = path.tempCString();

            Status newStatus;
            DigestType!Hash newChecksum;

            if (lstat(tmpPath, &statbuf) != 0)
            {
                if (errno == ENOENT)
                    newStatus = Status.missing;
                else
                    throw new SysException("Failed to stat resource");
            }
            else if ((statbuf.st_mode & S_IFMT) == S_IFREG)
            {
                newChecksum = digestFile!Hash(path);
                newStatus = Status.file;
            }
            else if ((statbuf.st_mode & S_IFMT) == S_IFDIR)
            {
                newChecksum = digestDir!Hash(tmpPath);
                newStatus = Status.directory;
            }
            else
            {
                // The resource is neither a file nor a directory. It could be a
                // special file such as a FIFO, block device, etc. In those
                // cases, we cannot be expected to track changes to those types
                // of files.
                newStatus = Status.unknown;
            }

            if (newStatus != status || checksum != newChecksum)
            {
                status = newStatus;
                checksum = newChecksum;
                return true;
            }

            return false;
        }
        else
        {
            static assert(false, "Not implemented yet.");
        }
    }

    /**
     * Returns true if the status of this resource is known.
     */
    @property bool statusKnown() const pure nothrow
    {
        return status != Status.unknown;
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

        status = Status.missing;
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
