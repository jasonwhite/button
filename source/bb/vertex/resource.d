/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module bb.vertex.resource;
import std.digest.digest : DigestType, isDigest;

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
    import io.file : File, FileFlags;
    import io.range : byChunk;

    ubyte[4096] buf;

    return digest!Hash(File(path, FileFlags.readExisting).byChunk(buf));
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
    DigestType!SHA256 checksum;

    this(ResourceId path, SysTime lastModified = Status.unknown, const(ubyte[]) checksum = [])
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
                auto checksum = digestFile!SHA256(path);
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
     * Deletes the resource from disk, but only if it is an output resource.
     */
    void remove() const nothrow
    {
        import std.file : unlink = remove, isFile;
        import io;

        // Only delete this file if we know about it. This helps prevent the
        // build system from haphazardly deleting files that were added to the
        // build description but never output by a task.
        if (!statusKnown)
            return;

        // TODO: Use rmdir instead if this is a directory.

        try
        {
            unlink(path);
        }
        catch (Exception e)
        {
        }
    }
}
