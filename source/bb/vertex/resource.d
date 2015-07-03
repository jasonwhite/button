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
     * Last time it was modified, according to the database
     */
    SysTime modified = SysTime.min;

    /**
     * Checksum of the file.
     *
     * TODO: Implement this.
     */
    ulong checksum;

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
    int opCmp()(auto ref Resource rhs)
    {
        import std.algorithm : cmp;
        return cmp(this.path, rhs.path);
    }
}
