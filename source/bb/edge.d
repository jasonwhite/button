/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.edge;

/**
 * Type of an edge.
 */
enum EdgeType
{
    /**
     * An explicit edge is one that was specified in the build description.
     */
    explicit,

    /**
     * An implicit edge is one that is reported by a task.
     *
     * Ideally, the set of implicit edges should always be a superset of the set
     * of explicit edges. If this is not the case, it implies one of two
     * problems:
     *
     *  1. The task is not reporting all dependencies.
     *  2. A superfluous dependency is specified in the build description.
     *
     * An over-specification of dependencies will not lead to a build error,
     * merely over-building. Thus, such a situation should only be reported as a
     * warning.
     */
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
