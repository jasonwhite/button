/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module bb.edge;

/**
 * An edge. Because the graph must be bipartite, an edge can never connect two
 * vertices of the same type.
 */
struct Edge(From, To)
    if (!is(From == To))
{
    From from;
    To to;

    /**
     * Compares two edges.
     */
    int opCmp()(const auto ref typeof(this) rhs) const pure nothrow
    {
        if (this.from != rhs.from)
            return this.from < rhs.from ? -1 : 1;

        if (this.to != rhs.to)
            return this.to < rhs.to ? -1 : 1;

        return 0;
    }

    /**
     * Returns true if both edges are the same.
     */
    bool opEquals()(const auto ref typeof(this) rhs) const pure
    {
        return from == rhs.from &&
               to == rhs.to;
    }
}

/// Ditto
struct Edge(From, To, Data)
    if (!is(From == To))
{
    From from;
    To to;

    Data data;

    /**
     * Compares two edges.
     */
    int opCmp()(const auto ref typeof(this) rhs) const pure
    {
        if (this.from != rhs.from)
            return this.from < rhs.from ? -1 : 1;

        if (this.to != rhs.to)
            return this.to < rhs.to ? -1 : 1;

        if (this.data != rhs.data)
            return this.data < rhs.data ? -1 : 1;

        return 0;
    }

    /**
     * Returns true if both edges are the same.
     */
    bool opEquals()(const auto ref typeof(this) rhs) const pure
    {
        return from == rhs.from &&
               to == rhs.to &&
               data == rhs.data;
    }
}
