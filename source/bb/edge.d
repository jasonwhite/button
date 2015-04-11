/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * TODO: Rename edges to links.
 */
module bb.edge;

import bb.index;

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
    Index!From from;
    Index!To to;

    EdgeType type;
}

alias EdgeIndex(From, To) = Index!(Edge!(From, To));
