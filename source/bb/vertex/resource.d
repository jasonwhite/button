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
    SysTime modified = SysTime.min;

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
    @property const(ResourceId) identifier() const pure nothrow
    {
        return path;
    }

    /**
     * Compares this resource with another.
     */
    int opCmp()(auto ref Resource rhs) const pure
    {
        import std.algorithm : cmp;
        return cmp(this.path, rhs.path);
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
    @property typeof(this) updated() const
    {
        import std.file : timeLastModified, FileException;

        immutable lastModified = timeLastModified(path, modified.init);

        if (lastModified != modified.init && lastModified != modified)
        {
            // TODO: Compute the checksum.
        }

        return Resource(path, lastModified, checksum);
    }

    /**
     * Returns true if this resource and the other have equal state. That is, if
     * they are up-to-date.
     */
    bool uptodate()(auto ref typeof(this) rhs) const pure nothrow
    {
        return this.modified == rhs.modified &&
               this.checksum == rhs.checksum;
    }
}
