/**
 * Copyright: Copyright Jason White, 2015
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
}
