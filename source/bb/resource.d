/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
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
    alias Name = Path;

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
     * Number of incoming edges. For a valid build description, this should
     * never be more than 1. That is, a resource should never be the output of
     * more than 1 task.
     */
    size_t incoming;

    /**
     * Number of incoming edges that have been satisfied. When this number
     * reaches the number of incoming edges, this node can be visited/processed.
     */
    size_t satisfied;

    /**
     * Last time it was modified, according to the database
     */
    SysTime modified;

    /**
     * A resource can be explicitly specified by the build description. That is,
     * it was added by the user. Otherwise, if the resource was added by the
     * build system, it is an implicit resource.
     */
    enum Type
    {
        explicit,
        implicit,
    }

    /// Ditto
    Type type = Type.explicit;

    /**
     * Constructs a resource from the given path. The path should be normalized
     * to ensure the uniqueness of this resource object.
     */
    this(string path, Type type = Type.explicit)
    {
        this.path = path;
        this.type = type;
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
