/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module button.graph;

import std.parallelism : TaskPool;

version (unittest)
{
    // Dummy types for testing
    private struct X { int x; alias x this; }
    private struct Y { int y; alias y this; }
    private alias G = Graph!(X, Y);
}

/**
 * A bipartite graph.
 */
class Graph(A, B, EdgeDataAB = size_t, EdgeDataBA = size_t)
    if (!is(A == B))
{
    /**
     * Find the opposite vertex type of the given vertex type.
     */
    alias Opposite(Vertex : A) = B;
    alias Opposite(Vertex : B) = A; /// Ditto

    /**
     * Uniform way of referencing edge data.
     */
    alias EdgeData(From : A, To : B) = EdgeDataAB;
    alias EdgeData(From : B, To : A) = EdgeDataBA;

    /**
     * Bookkeeping data associated with each vertex.
     *
     * FIXME: A class is only used here such that it can be used with the
     * synchronized statement. A less heavy-weight implementation should be used
     * instead.
     */
    static class Data
    {
        // Number of incoming edges for this vertex.
        size_t degreeIn;

        // Number of incoming edges for vertices who have changed or not
        // changed. The sum of these two variables will always be <= degreeIn.
        size_t changed, unchanged;

        void reset()
        {
            changed = 0;
            unchanged = 0;
        }
    }

    private
    {
        // Number of incoming edges
        Data[A] _dataA;
        Data[B] _dataB;

        // Edges from A -> B
        EdgeData!(A, B)[B][A] neighborsA;

        // Edges from B -> A
        EdgeData!(B, A)[A][B] neighborsB;

        // Uniform way of accessing data structures for each vertex type.
        alias neighbors(Vertex : A) = neighborsA;
        alias neighbors(Vertex : B) = neighborsB;
        alias _data(Vertex : A)  = _dataA;
        alias _data(Vertex : B)  = _dataB;
    }

    enum isVertex(Vertex) = is(Vertex : A) || is(Vertex : B);
    enum isEdge(From, To) = isVertex!From && isVertex!To;

    /**
     * Returns the number of vertices for the given type.
     */
    @property size_t length(Vertex)() const pure nothrow
        if (isVertex!Vertex)
    {
        return neighbors!Vertex.length;
    }

    /**
     * Returns true if the graph is empty.
     */
    @property bool empty() const pure nothrow
    {
        return length!A == 0 && length!B == 0;
    }

    /**
     * Returns data associated with the given vertex.
     */
    Data data(Vertex)(Vertex v) const pure
    {
        return _data!Vertex[v];
    }

    /**
     * Returns the number of edges going into the given vertex.
     */
    size_t degreeIn(Vertex)(Vertex v) const pure
    {
        return _data!Vertex[v].degreeIn;
    }

    /**
     * Returns the number of edges going out of the given vertex.
     */
    size_t degreeOut(Vertex)(Vertex v) const pure
    {
        return neighbors!Vertex[v].length;
    }

    /**
     * Adds a vertex if it does not already exist.
     */
    void put(Vertex)(Vertex v) pure
        if (isVertex!Vertex)
    {
        if (v !in neighbors!Vertex)
        {
            neighbors!Vertex[v] = neighbors!Vertex[v].init;
            _data!Vertex[v] = new Data();
        }
    }

    /**
     * Removes a vertex and all the incoming and outgoing edges associated with
     * it.
     */
    void remove(Vertex)(Vertex v) pure
        if (isVertex!Vertex)
    {
        neighbors!Vertex.remove(v);
        _data!Vertex.remove(v);
    }

    unittest
    {
        auto g = new G();

        assert(g.empty);

        g.put(X(1));
        g.put(Y(1));
        g.put(X(1));
        g.put(Y(1));

        assert(!g.empty);

        assert(g.length!X == 1);
        assert(g.length!Y == 1);

        g.remove(X(1));

        assert(g.length!X == 0);
        assert(g.length!Y == 1);

        g.remove(Y(1));

        assert(g.length!X == 0);
        assert(g.length!Y == 0);
    }

    /**
     * Adds an edge. Both vertices must be added to the graph first.
     */
    void put(A from, B to, EdgeDataAB data = EdgeDataAB.init)
    {
        assert(from in neighbors!A, "Attempted to add edge from non-existent vertex");
        assert(to in neighbors!B, "Attempted to add edge to non-existent vertex");

        if (to !in neighbors!A[from])
        {
            neighbors!A[from][to] = data;
            ++_data!B[to].degreeIn;
        }
    }

    void put(B from, A to, EdgeDataBA data = EdgeDataBA.init)
    {
        assert(from in neighbors!B, "Attempted to add edge from non-existent vertex");
        assert(to in neighbors!A, "Attempted to add edge to non-existent vertex");

        if (to !in neighbors!B[from])
        {
            neighbors!B[from][to] = data;
            ++_data!A[to].degreeIn;
        }
    }

    unittest
    {
        auto g = new G();
        g.put(X(1));
        g.put(Y(1));
        g.put(X(1), Y(1));
        g.put(X(1), Y(1));
        assert(g.degreeIn(Y(1)) == 1);
    }

    /**
     * Removes an edge.
     */
    void remove(From, To)(From from, To to) pure
        if (isEdge!(From, To))
    {
        assert(to in neighbors!From[from], "Attempted to remove non-existent edge");

        neighbors!From[from].remove(to);
        --_data!To[to].degreeIn;
    }

    unittest
    {
        auto g = new G();
        g.put(X(1));
        g.put(Y(1));
        g.put(X(1), Y(1));

        assert(g.length!X == 1);
        assert(g.length!Y == 1);
        assert(g.degreeIn(Y(1)) == 1);

        g.remove(X(1), Y(1));

        assert(g.length!X == 1);
        assert(g.length!Y == 1);
        assert(g.degreeIn(Y(1)) == 0);
    }

    /**
     * Returns a range of vertices of the given type.
     */
    @property auto vertices(Vertex)() const pure
        if (isVertex!Vertex)
    {
        return neighbors!Vertex.byKey;
    }

    static struct Edges(From, To)
    {
        import button.edge;
        alias Neighbors = EdgeData!(From, To)[To][From];
        alias E = Edge!(From, To, EdgeData!(From, To));

        private const(Neighbors) _neighbors;

        this(const(Neighbors) neighbors)
        {
            _neighbors = neighbors;
        }

        int opApply(int delegate(E) dg) const
        {
            int result = 0;

            foreach (j; _neighbors.byKeyValue())
            {
                foreach (k; j.value.byKeyValue())
                {
                    result = dg(E(j.key, k.key, k.value));
                    if (result) break;
                }
            }

            return result;
        }
    }

    /**
     * Returns an array of edges of the given type.
     */
    auto edges(From, To)() const pure
        if (isEdge!(From, To))
    {
        return Edges!(From, To)(neighbors!From);
    }

    /**
     * Returns a range of outgoing neighbors from the given node.
     */
    auto outgoing(Vertex)(Vertex v) pure
        if (isVertex!Vertex)
    {
        return neighbors!Vertex[v];
    }

    /**
     * Bookkeeping structure for helping keep track of vertices that have been
     * visited.
     */
    static struct Visited(Value)
    {
        Value[A] visitedA;
        Value[B] visitedB;

        alias visited(V : A) = visitedA;
        alias visited(V : B) = visitedB;

        /**
         * Adds a vertex to the list of visited vertices.
         */
        void put(Vertex)(Vertex v, Value value)
            if (isVertex!Vertex)
        {
            visited!Vertex[v] = value;
        }

        /**
         * Remove a vertex from the list of visited vertices.
         */
        void remove(Vertex)(Vertex v)
            if (isVertex!Vertex)
        {
            visited!Vertex.remove(v);
        }

        /**
         * Returns true if the given vertex has been visited.
         */
        inout(Value*) opBinaryRight(string op, Vertex)(Vertex v) inout
            if (op == "in")
        {
            return v in visited!Vertex;
        }
    }

    /**
     * Helper function for starting a traversal from a single vertex.
     */
    private void traverse(alias visitThis, alias visitThat, Context, Vertex)
        (TaskPool pool, Context ctx, Vertex v, bool parentChanged)
        if (isVertex!Vertex)
    {
        import std.parallelism : parallel;
        import core.atomic : atomicOp;

        auto data = v in _data!Vertex;

        assert(data && *data !is null, "Vertex does not exist.");

        synchronized (*data)
        {
            final switch (parentChanged)
            {
                case false: ++data.unchanged; break;
                case true: ++data.changed; break;
            }

            // Unless everyone has arrived at the junction, do not proceed.
            if ((data.changed + data.unchanged) < data.degreeIn)
                return;
        }

        // Reset the counts so that it is safe to traverse the graph again.
        scope (exit) data.reset();

        // If none of our dependencies changed, then don't do any work.
        // Propagate the change status downward.
        //immutable changed = data.changed > 0 && visitThis(ctx, v, data.degreeIn);
        immutable changed = visitThis(ctx, v, data.degreeIn, data.changed);

        Throwable head;
        Throwable tail;

        // Visit all our children. If any of them throw up, then catch it, put
        // it in a bag, and save it for later.
        foreach (child; pool.parallel(neighbors!Vertex[v].byKey(), 1))
        {
            try
                traverse!(visitThat, visitThis)(pool, ctx, child, changed);
            catch (Exception e)
            {
                synchronized (*data)
                {
                    if (head is null)
                    {
                        head = e;
                    }
                    else
                    {
                        e.next = head;
                        head = e;
                    }
                }
            }
        }

        if (head !is null)
            throw head;
    }

    /**
     * Traverses the entire graph depth-first calling the given visitor
     * functions.
     *
     * TODO: Use a queue and randomize the build order instead. This should give
     * better performance on average and help catch race conditions.
     */
    void traverse(alias visitA, alias visitB, Context)
        (Context ctx, TaskPool pool)
    {
        import std.parallelism : parallel;
        import std.algorithm.iteration : filter;
        import core.sync.mutex : Mutex;

        auto mutex = new Mutex();

        Throwable head;

        foreach (v; pool.parallel(vertices!A.filter!(v => degreeIn(v) == 0), 1))
        {
            try
                traverse!(visitA, visitB)(pool, ctx, v, true);
            catch (Exception e)
            {
                synchronized (mutex)
                {
                    if (head is null)
                    {
                        head = e;
                    }
                    else
                    {
                        e.next = head;
                        head = e;
                    }
                }
            }
        }

        foreach (v; pool.parallel(vertices!B.filter!(v => degreeIn(v) == 0), 1))
        {
            try
                traverse!(visitB, visitA)(pool, ctx, v, true);
            catch (Exception e)
            {
                synchronized (mutex)
                {
                    if (head is null)
                    {
                        head = e;
                    }
                    else
                    {
                        e.next = head;
                        head = e;
                    }
                }
            }
        }

        if (head !is null)
            throw head;
    }

    /**
     * Helper function for doing a depth-first search to construct a subgraph.
     */
    private void subgraphDFS(Vertex)(Vertex v, typeof(this) g, ref Visited!bool visited)
    {
        if (v in visited)
            return;

        visited.put(v, true);

        g.put(v);

        foreach (child; outgoing(v).byKeyValue())
        {
            subgraphDFS(child.key, g, visited);
            g.put(v, child.key, child.value);
        }
    }

    /**
     * Creates a subgraph using the given roots. This is done by traversing the
     * graph and only adding the vertices and edges that we come across.
     */
    typeof(this) subgraph(const(A[]) rootsA, const(B[]) rootsB)
    {
        auto g = new typeof(return)();

        Visited!bool visited;

        foreach (v; rootsA)
            subgraphDFS(v, g, visited);

        foreach (v; rootsB)
            subgraphDFS(v, g, visited);

        return g;
    }

    /**
     * Returns the set of changes between the vertices in this graph and the
     * other.
     */
    auto diffVertices(Vertex)(const ref typeof(this) other) const
        if (isVertex!Vertex)
    {
        import std.array : array;
        import std.algorithm.iteration : uniq;
        import std.algorithm.sorting : sort;
        import util.change;

        auto theseVertices = this.neighbors!Vertex.byKey().array.sort().uniq;
        auto thoseVertices = other.neighbors!Vertex.byKey().array.sort().uniq;

        return changes(theseVertices, thoseVertices);
    }

    /**
     * Returns the set of changes between the edges in this graph and the other.
     */
    auto diffEdges(From, To)(const ref typeof(this) other) const
        if (isEdge!(From, To))
    {
        import std.array : array;
        import std.algorithm.iteration : uniq;
        import std.algorithm.sorting : sort;
        import util.change;

        auto theseEdges = this.edges!(From, To).array.sort().uniq;
        auto thoseEdges = other.edges!(From, To).array.sort().uniq;

        return changes(theseEdges, thoseEdges);
    }

    /**
     * Bookkeeping data for each vertex used by Tarjan's strongly connected
     * components algorithm.
     */
    private static struct TarjanData
    {
        // Index of this node.
        size_t index;

        // The smallest index of any vertex known to be reachable from this
        // vertex. If this value is equal to the index of this node, then it is
        // the root of the strongly connected component (SCC).
        size_t lowlink;

        // True if this vertex is currently in the depth-first search stack.
        bool inStack;
    }

    /**
     * A strongly connected component.
     */
    static struct SCC
    {
        A[] _verticesA;
        B[] _verticesB;

        /**
         * Uniform access to the vertices.
         */
        alias vertices(Vertex : A) = _verticesA;
        alias vertices(Vertex : B) = _verticesB;
    }

    /**
     * Range of strongly connected components in the graph.
     */
    private static struct Tarjan
    {
        alias G = Graph!(A, B, EdgeDataAB, EdgeDataBA);

        private
        {
            import std.array : Appender;

            G _graph;

            size_t index;

            TarjanData[A] _dataA;
            TarjanData[B] _dataB;

            Appender!(A[]) _stackA;
            Appender!(B[]) _stackB;

            alias data(Vertex : A)  = _dataA;
            alias data(Vertex : B)  = _dataB;
            alias stack(Vertex : A) = _stackA;
            alias stack(Vertex : B) = _stackB;
        }

        this(G graph)
        {
            _graph = graph;
        }

        int stronglyConnected(V1)(V1 v, scope int delegate(SCC c) dg)
        {
            import std.algorithm.comparison : min;
            import std.array : appender;

            alias V2 = Opposite!V1;

            stack!V1.put(v);
            data!V1[v] = TarjanData(index, index, true);
            ++index;

            auto p = v in data!V1;

            // Consider successors of this vertex
            foreach (w; _graph.neighbors!V1[v].byKey())
            {
                auto c = w in data!V2; // Child data
                if (!c)
                {
                    // Successor w has not yet been visited, recurse on it
                    if (immutable result = stronglyConnected(w, dg))
                        return result;

                    p.lowlink = min(p.lowlink, data!V2[w].lowlink);
                }
                else if (c.inStack)
                {
                    // Successor w is on the stack and hence in the current SCC
                    p.lowlink = min(p.lowlink, c.index);
                }
            }

            // If v is a root vertex, pop the stacks and generate an SCC
            if (p.lowlink == p.index)
            {
                auto scc = SCC();

                auto sccA = appender!(V1[]);
                auto sccB = appender!(V2[]);

                while (true)
                {
                    auto successorA = stack!V1.data[stack!V1.data.length-1];
                    stack!V1.shrinkTo(stack!V1.data.length - 1);
                    data!V1[successorA].inStack = false;
                    sccA.put(successorA);

                    // Only pop the other stack if there is something top pop
                    // and the top is part of the same SCC.
                    if (stack!V2.data.length)
                    {
                        auto successorB = stack!V2.data[stack!V2.data.length-1];

                        if (data!V2[successorB].lowlink == p.lowlink)
                        {
                            stack!V2.shrinkTo(stack!V2.data.length - 1);
                            data!V2[successorB].inStack = false;
                            sccB.put(successorB);
                        }
                    }

                    // Pop the stack until we get back to this vertex
                    if (successorA == v)
                        break;
                }

                scc.vertices!V1 = sccA.data;
                scc.vertices!V2 = sccB.data;

                if (immutable result = dg(scc))
                    return result;
            }

            return 0;
        }

        int opApply(scope int delegate(SCC c) dg)
        {
            foreach (v; _graph.vertices!A)
            {
                if (v !in data!A)
                {
                    if (immutable result = stronglyConnected(v, dg))
                        return result;
                }
            }

            foreach (v; _graph.vertices!B)
            {
                if (v !in data!B)
                {
                    if (immutable result = stronglyConnected(v, dg))
                        return result;
                }
            }

            return 0;
        }
    }

    /**
     * Using Tarjan's algorithm, returns a range of strongly connected
     * components (SCCs). Each SCC consists of a list of vertices that are
     * strongly connected. The SCCs are listed in reverse topological order.
     *
     * Time complexity: O(|v| + |E|)
     *
     * By filtering for SCCs that consist of more than 1 vertex, we can find and
     * display all the cycles in a graph.
     */
    @property auto tarjan()
    {
        return Tarjan(this);
    }

    /**
     * Returns an array of cycles in the graph.
     */
    @property immutable(SCC)[] cycles()
    {
        import std.array : appender;
        import std.exception : assumeUnique;

        auto arr = appender!(SCC[]);

        foreach (scc; tarjan)
        {
            if (scc.vertices!A.length &&
                scc.vertices!B.length)
            {
                arr.put(scc);
            }
        }

        return assumeUnique(arr.data);
    }
}

unittest
{
    import std.algorithm.comparison : equal;
    import std.array : array;

    {
        auto g = new G();
        g.put(X(1));

        assert(g.tarjan.array.equal([G.SCC([X(1)], [])]));
    }

    {
        auto g = new G();
        g.put(Y(1));

        assert(g.tarjan.array.equal([G.SCC([], [Y(1)])]));
    }

    {
        // Simplest possible cycle (for a bipartite graph)
        auto g = new G();
        g.put(X(1));
        g.put(Y(1));
        g.put(X(1), Y(1));
        g.put(Y(1), X(1));

        // There should be only 1 connected component, encompassing the entire
        // graph
        assert(g.tarjan.array.equal([G.SCC([X(1)], [Y(1)])]));
    }

    {
        auto g = new G();
        g.put(X(1));
        g.put(Y(2));
        g.put(X(3));
        g.put(Y(4));
        g.put(Y(5));
        g.put(X(6));

        g.put(X(1), Y(2));
        g.put(Y(2), X(3));
        g.put(X(3), Y(4));
        g.put(X(3), Y(5));
        g.put(Y(4), X(6));
        g.put(X(6), Y(4));
        g.put(Y(5), X(1));

        assert(g.tarjan.array.equal([
            G.SCC([X(6)], [Y(4)]),
            G.SCC([X(1), X(3)], [Y(2), Y(5)]),
        ]));
    }
}

unittest
{
    import std.stdio;

    auto g = new G();
    g.put(X(1));
    g.put(Y(1));
    g.put(X(1), Y(1));

    auto g2 = g.subgraph([X(1)], [Y(1)]);
    assert(g2.length!X == 1);
    assert(g2.length!Y == 1);
}

unittest
{
    import std.algorithm.comparison : equal;
    import util.change;
    import button.edge;

    alias C = Change;

    auto g1 = new G();
    g1.put(X(1));
    g1.put(X(2));
    g1.put(Y(1));
    g1.put(X(1), Y(1));
    g1.put(X(2), Y(1));

    auto g2 = new G();
    g2.put(X(1));
    g2.put(X(3));
    g2.put(Y(1));
    g2.put(Y(2));
    g2.put(X(1), Y(1));

    assert(g1.diffVertices!X(g2).equal([
        C!X(X(1), ChangeType.none),
        C!X(X(2), ChangeType.removed),
        C!X(X(3), ChangeType.added),
    ]));

    assert(g1.diffVertices!Y(g2).equal([
        C!Y(Y(1), ChangeType.none),
        C!Y(Y(2), ChangeType.added),
    ]));

    alias E = Edge!(X, Y, size_t);

    assert(g1.diffEdges!(X, Y)(g2).equal([
        C!E(E(X(1), Y(1), 0), ChangeType.none),
        C!E(E(X(2), Y(1), 0), ChangeType.removed),
    ]));
}
