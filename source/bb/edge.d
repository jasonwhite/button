/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.edge;

/**
 * A resource can be explicitly specified by the build description. That is, the
 * edge connecting a task and resource was added by the user. Otherwise, if the
 * edge was added by the build system, it is an implicit resource.
 */
enum EdgeType
{
    explicit,
    implicit,
}

/**
 * An edge. Because the graph must be bipartite, an edge can never connect two
 * vertices of the same type.
 */
struct Edge(From, To)
    if (!is(From == To))
{
    From from;
    To to;

    EdgeType type;
}
