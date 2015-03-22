/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.resource;

/**
 * A representation of a file on the disk.
 */
struct Resource
{
    import std.datetime : SysTime;

    alias Path = string;
    alias Identifier = Path;

    /**
     * File path to the resource. To ensure uniqueness, this should never be
     * changed after construction.
     */
    immutable Path path;

    /**
     * Unique identifier for this resource.
     */
    alias identifier = path;

    /**
     * Last time it was modified, according to the database
     */
    SysTime modified = SysTime.min;

    /**
     * Constructs a resource from the given path. The path should be normalized
     * to ensure the uniqueness of this resource object.
     */
    this(string path)
    {
        this.path = path;
    }

    /**
     * Returns a string representation of this resource. This is just the path
     * to the resource.
     */
    string toString() const pure nothrow
    {
        return path;
    }
}
