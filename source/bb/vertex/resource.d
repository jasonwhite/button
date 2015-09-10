/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.vertex.resource;

/**
 * A resource identifier.
 */
alias ResourceId = string;

/**
 * A representation of a file on the disk.
 */
struct Resource
{
    import std.datetime : SysTime;

    /**
     * File path to the resource. To ensure uniqueness, this should never be
     * changed after construction.
     */
    ResourceId path;

    /**
     * Last time the file was modified, according to the database. If this is
     * SysTime.min, then it is taken to mean that the file does not exist.
     */
    SysTime lastModified = SysTime.min;

    /**
     * Checksum of the file.
     */
    ulong checksum = 0;

    /**
     * Returns a string representation of this resource. This is just the path
     * to the resource.
     */
    string toString() const pure nothrow
    {
        return path;
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

    unittest
    {
        assert(Resource("a") < Resource("b"));
        assert(Resource("b") > Resource("a"));
    }

    /**
     * Returns a new resource with an updated time stamp and checksum.
     *
     * If this resource is not equal to the returned resource, then this
     * resource is has changed (i.e., considered out of date).
     *
     * Note that the checksum is not recomputed if the modification time is the
     * same.
     */
    @property typeof(this) update() const
    {
        import std.file : timeLastModified, FileException;

        immutable lastModified = timeLastModified(path, this.lastModified.init);

        if (lastModified != this.lastModified.init && lastModified != this.lastModified)
        {
            // TODO: Compute the checksum.
        }

        return Resource(path, lastModified, checksum);
    }

    unittest
    {
        assert(Resource("test", SysTime(1), 1) == Resource("test", SysTime(1), 1));
        assert(Resource("test", SysTime(1), 1) != Resource("test", SysTime(2), 2));
    }

    /**
     * Deletes the resource from disk, but only if it is an output resource.
     */
    void remove() const
    {
        import std.file : unlink = remove, isFile;
        import io;

        println(":: Deleting `", path, "`");

        // TODO: Delete for real when this is verified to be safe
        //if (lastModified != lastModified.init)
            //unlink(path);
    }
}
