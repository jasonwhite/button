/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.graph;

version (unittest)
{
    // Dummy types for testing
    private struct X { int x; alias x this; }
    private struct Y { int y; alias y this; }
}

/**
 * A bipartite graph.
 */
struct Graph(A, B, EdgeData)
    if (!is(A == B))
{
    private
    {
        // Edges from A -> B
        EdgeData[B][A] neighborsA;

        // Edges from B -> A
        EdgeData[A][B] neighborsB;

        // Uniform way of accessing vertices.
        alias neighbors(Vertex : A) = neighborsA;
        alias neighbors(Vertex : B) = neighborsB;
    }

    /**
     * Returns the number of vertices for the given type.
     */
    @property size_t length(Vertex)() const pure nothrow
    {
        return neighbors!Vertex.length;
    }

    /**
     * Adds a vertex.
     */
    void add(Vertex)(Vertex v) pure
    {
        if (v !in neighbors!Vertex)
            neighbors!Vertex[v] = neighbors!Vertex[v].init;
    }

    /**
     * Removes a vertex and all the incoming and outgoing edges associated with
     * it.
     */
    void remove(Vertex)(Vertex v) pure
    {
        neighbors!Vertex.remove(v);
    }

    unittest
    {
        auto g = Graph!(X,Y,int)();
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
    void add(From,To)(From from, To to, EdgeData data) pure
    {
        neighbors!From[from][to] = data;
    }

    unittest
    {
        auto g = Graph!(X,Y,int)();
        g.add(X(1));
        g.add(Y(1));
        g.add(X(1), Y(1), 42);
    }

    /**
     * Removes an edge.
     */
    void remove(From, To)(From from, To to) pure
    {
        neighbors!From[from].remove(to);
    }

    unittest
    {
        auto g = Graph!(X,Y,int)();
        g.add(X(1));
        g.add(Y(1));
        g.add(X(1), Y(1), 42);

        assert(g.length!X == 1);
        assert(g.length!Y == 1);

        g.remove(X(1), Y(1));

        assert(g.length!X == 1);
        assert(g.length!Y == 1);
    }

    /**
     * Returns a range of vertices.
     */
    @property
    auto vertices(Vertex)() const pure
    {
        return neighbors!Vertex.byKey;
    }

    /**
     * Returns a range of edges.
     *
     * TODO
     */
    auto edges(From, To)() const pure
    {
        foreach (i; vertices!From)
        {
            foreach (j; neighbors(i))
            {
                //yield (i, j)
            }
        }
    }

    /**
     * Returns a range of outgoing neighbors from the given node.
     */
    auto outgoing(Vertex)(Vertex v) pure
    {
        return neighbors!Vertex[v];
    }

    /**
     * Traverses the graph calling the given visitor functions for each vertex.
     * Each visitor function should return true to continue visiting the
     * vertex's children.
     *
     * TODO: Parallelize this.
     */
    void traverse(const(A)[] rootsA, const(B)[] rootsB,
         bool delegate(A) visitVertexA, bool delegate(B) visitVertexB,
         void delegate(A,B,EdgeData) visitEdgeAB, void delegate(B,A,EdgeData) visitEdgeBA
         )
    {
        import std.container.rbtree : redBlackTree;

        // Keep track of which vertices have been visited.
        auto visitedA = redBlackTree!A;
        auto visitedB = redBlackTree!B;

        visitedA.insert(rootsA);
        visitedB.insert(rootsB);

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
                foreach (child; outgoing(v).byKeyValue())
                {
                    if (child.key in visitedB) continue;
                    visitEdgeAB(v, child.key, child.value);
                    visitedB.insert(child.key);
                    queueB ~= child.key;
                }
            }

            while (queueB.length > 0)
            {
                // Pop off a vertex
                auto v = queueB[$-1]; queueB.length -= 1;

                // Visit the vertex
                if (!visitVertexB(v)) continue;

                // Queue its children.
                foreach (child; outgoing(v).byKeyValue())
                {
                    if (child.key in visitedA) continue;
                    visitEdgeBA(v, child.key, child.value);
                    visitedA.insert(child.key);
                    queueA ~= child.key;
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
    typeof(this) subgraph(const(A[]) rootsA, const(B[]) rootsB)
    {
        auto g = typeof(return)();

        bool visitVertex(Vertex)(Vertex v)
        {
            g.add(v);
            return true;
        }

        void visitEdge(From, To, EdgeData)(From from, To to, EdgeData data)
        {
            g.add(from, to, data);
        }

        traverse(rootsA, rootsB,
            &visitVertex!A, &visitVertex!B,
            &visitEdge!(A,B,EdgeData), &visitEdge!(B,A,EdgeData)
            );

        return g;
    }

    /**
     * Returns a set of differences between this graph and another.
     *
     * The set of differences includes added/removed vertices and edges.
     */
    auto diff(const ref Graph!(A, B, EdgeData) other) const pure
    {
        // TODO
    }
}

unittest
{
    import std.stdio;

    auto g = Graph!(X, Y, int)();
    g.add(X(1));
    g.add(Y(1));
    g.add(X(1), Y(1), 42);

    auto g2 = g.subgraph([X(1)], [Y(1)]);
    assert(g2.length!X == 1);
    assert(g2.length!Y == 1);
}
