/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.graph;

version (unittest)
{
    // Dummy types for testing
    private struct X { int x; }
    private struct Y { int y; }
}

/**
 * Stupid set implementation using an associative array.
 *
 * This data structure and more should REALLY be in the standard library.
 */
private struct Set(T)
{
    private bool[T] _items;

    /**
     * Initialize with a list of items.
     */
    this(const(T[]) items) pure
    {
        add(items);
    }

    /**
     * Adds a item to the set.
     */
    void add(T item) pure
    {
        _items[item] = typeof(_items[item]).init;
    }

    // Ditto
    void add(const(T[]) items) pure
    {
        foreach (item; items)
            add(item);
    }

    /**
     * Removes an item from the set.
     */
    void remove(T item) pure
    {
        _items.remove(item);
    }

    /**
     * Returns the number of items in the set.
     */
    @property
    size_t length() const pure nothrow
    {
        return _items.length;
    }

    /**
     * Returns a range of items in the set. There are no guarantees placed on
     * the order of these items.
     */
    @property auto items() const pure nothrow
    {
        return _items.byKey;
    }

    /**
     * Returns true if the item is in the set.
     */
    bool opIn_r(T item) const pure nothrow
    {
        return (item in _items) != null;
    }
}

/**
 * Bipartite graph.
 */
struct Graph(A, B)
    if (!is(A == B))
{
    private
    {
        // NOTE: Using a MultiSet instead of a Set will allow duplicate edges.

        // Incoming edges.
        Set!B[A] neighborsInA;
        Set!A[B] neighborsInB;

        // Outgoing edges.
        Set!B[A] neighborsOutA;
        Set!A[B] neighborsOutB;

        // Uniform way of accessing vertices.
        alias neighborsIn(Vertex : A) = neighborsInA;
        alias neighborsIn(Vertex : B) = neighborsInB;
        alias neighborsOut(Vertex : A) = neighborsOutA;
        alias neighborsOut(Vertex : B) = neighborsOutB;
    }

    invariant
    {
        assert(neighborsInA.length == neighborsOutA.length);
        assert(neighborsInB.length == neighborsOutB.length);
    }

    /**
     * Returns the number of vertices for the given type.
     */
    @property size_t length(Vertex)() const pure nothrow
    {
        return neighborsIn!Vertex.length;
    }

    /**
     * Adds a vertex.
     */
    void add(Vertex)(Vertex v) pure
    {
        if (v !in neighborsIn!Vertex)
            neighborsIn!Vertex[v] = typeof(neighborsIn!Vertex[v])();

        if (v !in neighborsOut!Vertex)
            neighborsOut!Vertex[v] = typeof(neighborsOut!Vertex[v])();
    }

    /// Ditto
    void add(Vertex)(const(Vertex[]) vertices) pure
    {
        foreach (v; vertices)
            add(v);
    }

    /**
     * Removes a vertex and all the incoming and outgoing edges associated with
     * it.
     *
     * FIXME: This function may never be needed by real code.
     */
    void remove(Vertex)(Vertex v) pure
    {
        neighborsIn!Vertex.remove(v);
        neighborsOut!Vertex.remove(v);
    }

    unittest
    {
        auto g = Graph!(X,Y)();
        g.add(X(1));
        g.add(Y(1));
        g.add(X(1));
        g.add(Y(1));

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
    void add(From,To)(From from, To to) pure
    {
        auto incoming = to in neighborsIn!To;
        assert(incoming, "Invalid vertex ID");
        incoming.add(from);

        auto outgoing = from in neighborsOut!From;
        assert(outgoing, "Invalid vertex ID");
        outgoing.add(to);
    }

    unittest
    {
        auto g = Graph!(X,Y)();
        g.add(X(1));
        g.add(Y(1));
        g.add(X(1), Y(1));
    }

    /**
     * Removes an edge.
     *
     * FIXME: This function may never be needed by real code.
     */
    void remove(From, To)(From from, To to) pure
    {
        neighborsIn!To[to].remove(from);
        neighborsOut!From[from].remove(to);
    }

    unittest
    {
        auto g = Graph!(X,Y)();
        g.add(X(1));
        g.add(Y(1));
        g.add(X(1));
        g.add(Y(1));

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
     * Returns a range of vertices.
     */
    auto vertices(Vertex)() const pure
    {
        return neighborsOut!Vertex.byKey;
    }

    /**
     * Returns a range of incoming edges to the given vertex.
     */
    auto incoming(Vertex)(Vertex v) const pure
    {
        return neighborsIn!Vertex[v].items;
    }

    /**
     * Returns a range of outgoing edges from the given vertex.
     */
    auto outgoing(Vertex)(Vertex v) const pure
    {
        return neighborsOut!Vertex[v].items;
    }

    /**
     * Number of incoming edges for the given vertex.
     */
    size_t degreeIncoming(Vertex)(Vertex v) const pure nothrow
    {
        return neighborsIn!Vertex[v].length;
    }

    /**
     * Number of outgoing edges for the given vertex.
     */
    size_t degreeOutgoing(Vertex)(Vertex v) const pure nothrow
    {
        return neighborsOut!Vertex[v].length;
    }

    /**
     * Traverses the graph calling the given visitor functions for each vertex.
     * Each visitor function should return true to continue visiting the
     * vertex's children.
     *
     * TODO: Parallelize this.
     */
    void traverse(const(A[]) rootsA, const(B[]) rootsB,
         bool delegate(A) visitVertexA, bool delegate(B) visitVertexB,
         void delegate(A,B) visitEdgeAB, void delegate(B,A) visitEdgeBA
         ) const
    {
        // Keep track of which vertices have been visited.
        auto visitedA = Set!A(rootsA);
        auto visitedB = Set!B(rootsB);

        // List of vertices queued to be visited. Vertices in the queue do not
        // depend on each other, and thus, can be visited in parallel.
        A[] queueA = rootsA.dup;
        B[] queueB = rootsB.dup;

        // Process both queues until they are empty.
        while (queueA.length > 0 || queueB.length > 0)
        {
            while (queueA.length > 0)
            {
                // Pop off a vertex
                auto v = queueA[$-1]; queueA.length -= 1;

                // Visit the vertex
                if (!visitVertexA(v)) continue;

                // Queue its children.
                foreach (child; outgoing(v))
                {
                    if (child in visitedB) continue;
                    visitEdgeAB(v, child);
                    visitedB.add(child);
                    queueB ~= child;
                }
            }

            while (queueB.length > 0)
            {
                // Pop off a vertex
                auto v = queueB[$-1]; queueB.length -= 1;

                // Visit the vertex
                if (!visitVertexB(v)) continue;

                // Queue its children.
                foreach (child; outgoing(v))
                {
                    if (child in visitedA) continue;
                    visitEdgeBA(v, child);
                    visitedA.add(child);
                    queueA ~= child;
                }
            }
        }
    }

    /**
     * Creates a subgraph using the given roots. This is done by traversing the
     * graph and only adding the vertices and edges that we come across.
     *
     * TODO: Simplify and parallelize this.
     */
    typeof(this) subgraph(const(A[]) rootsA, const(B[]) rootsB) const
    {
        auto g = typeof(return)();

        bool visitVertex(Vertex)(Vertex v)
        {
            g.add(v);
            return true;
        }

        void visitEdge(From, To)(From from, To to)
        {
            g.add(from, to);
        }

        traverse(rootsA, rootsB,
            &visitVertex!A, &visitVertex!B,
            &visitEdge!(A,B), &visitEdge!(B,A)
            );

        return g;
    }
}

unittest
{
    auto g = Graph!(X,Y)();
    g.add(X(1));
    g.add(Y(1));
    g.add(X(1), Y(1));

    auto g2 = g.subgraph([X(1)], [Y(1)]);
    assert(g2.length!X == 1);
    assert(g2.length!Y == 1);
}
