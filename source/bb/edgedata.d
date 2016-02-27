/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module bb.edgedata;

/**
 * The type of an edge.
 */
enum EdgeType
{
    /**
     * An explicit edge is one that was specified in the build description.
     *
     * The explicit specification of an edge from a task to a resource should be
     * considered a contract that must be fulfilled by the task. If the task
     * does not report that resource as an output, the task is marked as failed.
     */
    explicit = 1 << 0,

    /**
     * An implicit edge is one that is reported by a task.
     *
     * The set of implicit edges should always be a superset of the set of
     * explicit edges. If this is not the case, it implies one of two problems:
     *
     *  1. A superfluous dependency is specified in the build description.
     *  2. The task is not reporting all dependencies.
     *
     * Case (1) causes no harm except over-building. However, case (2) should be
     * considered an error because explicit edges are a contract that the task
     * must fulfill. It is not possible to differentiate between these two
     * cases. Thus, the more conservative approach is taken to always consider
     * it an error if the set of explicit edges is not a subset of the set of
     * implicit edges.
     */
    implicit = 1 << 1,

    /**
     * An edge is both explicit and implicit if it is in the build description
     * and reported by a task.
     */
    both = explicit | implicit,
}
