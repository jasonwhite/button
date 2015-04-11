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
 * An edge. Because the graph is bipartite, an edge can never link two nodes of
 * the same type.
 */
struct Edge(From, To)
    if (!is(From == To))
{
    import bb.node.index : NodeIndex;

    NodeIndex!From from;
    NodeIndex!To to;

    EdgeType type;
}

/**
 * Index of an edge.
 */
struct EdgeIndex(From, To)
{
    ulong index;
    alias index this;
}
