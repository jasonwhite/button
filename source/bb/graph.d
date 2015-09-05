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
    private alias G = Graph!(X, Y, int);
}

import bb.edge;

/**
 * A bipartite graph.
 */
struct Graph(A, B)
    if (!is(A == B))
{
    private
    {
        // Edges from A -> B
        bool[B][A] neighborsA;

        // Edges from B -> A
        bool[A][B] neighborsB;

        // Uniform way of accessing vertices.
        alias neighbors(Vertex : A) = neighborsA;
        alias neighbors(Vertex : B) = neighborsB;
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
     * Adds a vertex.
     */
    void put(Vertex)(Vertex v) pure
        if (isVertex!Vertex)
    {
        if (v !in neighbors!Vertex)
            neighbors!Vertex[v] = neighbors!Vertex[v].init;
    }

    /**
     * Removes a vertex and all the incoming and outgoing edges associated with
     * it.
     */
    void remove(Vertex)(Vertex v) pure
        if (isVertex!Vertex)
    {
        neighbors!Vertex.remove(v);
    }

    unittest
    {
        auto g = G();
        g.put(X(1));
        g.put(Y(1));
        g.put(X(1));
        g.put(Y(1));

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
    void put(From,To)(From from, To to) pure
        if (isEdge!(From, To))
    {
        neighbors!From[from][to] = true;
    }

    unittest
    {
        auto g = G();
        g.put(X(1));
        g.put(Y(1));
        g.put(X(1), Y(1), 42);
    }

    /**
     * Removes an edge.
     */
    void remove(From, To)(From from, To to) pure
        if (isEdge!(From, To))
    {
        neighbors!From[from].remove(to);
    }

    unittest
    {
        auto g = G();
        g.put(X(1));
        g.put(Y(1));
        g.put(X(1), Y(1), 42);

        assert(g.length!X == 1);
        assert(g.length!Y == 1);

        g.remove(X(1), Y(1));

        assert(g.length!X == 1);
        assert(g.length!Y == 1);
    }

    /**
     * Returns a range of vertices of the given type.
     */
    @property
    auto vertices(Vertex)() const pure
        if (isVertex!Vertex)
    {
        return neighbors!Vertex.byKey;
    }

    /**
     * Returns an array of edges of the given type.
     */
    auto edges(From, To)() const pure
        if (isEdge!(From, To))
    {
        import std.array : appender;

        auto edges = appender!(Edge!(From, To)[]);

        foreach (j; neighbors!From.byKeyValue())
            foreach (k; j.value.byKeyValue())
                edges.put(Edge!(From, To)(j.key, k.key));

        return edges.data;
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
     * Traverses the graph calling the given visitor functions for each vertex.
     * Each visitor function should return true to continue visiting the
     * vertex's children.
     *
     * TODO: Parallelize this.
     */
    void traverse(const(A)[] rootsA, const(B)[] rootsB,
         bool delegate(A) visitVertexA, bool delegate(B) visitVertexB,
         void delegate(A,B) visitEdgeAB, void delegate(B,A) visitEdgeBA
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
                    visitEdgeAB(v, child.key);
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
                    visitEdgeBA(v, child.key);
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
            g.put(v);
            return true;
        }

        void visitEdge(From, To)(From from, To to)
        {
            g.put(from, to);
        }

        traverse(rootsA, rootsB,
            &visitVertex!A, &visitVertex!B,
            &visitEdge!(A,B), &visitEdge!(B,A)
            );

        return g;
    }

    /**
     * Returns the set of changes between the vertices in this graph and the
     * other.
     */
    auto diffVertices(Vertex)(const ref typeof(this) other) const pure
        if (isVertex!Vertex)
    {
        import std.array : array;
        import std.algorithm.sorting : sort;
        import change;

        auto theseVertices = this.neighbors!Vertex.byKey().array.sort();
        auto thoseVertices = other.neighbors!Vertex.byKey().array.sort();

        return changes(theseVertices, thoseVertices);
    }

    /**
     * Returns the set of changes between the edges in this graph and the other.
     */
    auto diffEdges(From, To)(const ref typeof(this) other) const pure
        if (isEdge!(From, To))
    {
        import std.algorithm.sorting : sort;
        import change;

        auto theseEdges = this.edges!(From, To).sort();
        auto thoseEdges = other.edges!(From, To).sort();

        return changes(theseEdges, thoseEdges);
    }

    import io.stream.types : isSink;

    /**
     * Generate input suitable for GraphViz.
     */
    void graphviz(Stream)(Stream stream)
        if (isSink!Stream)
    {
        import io.text;
        stream.println("digraph G {");
        scope (success) stream.println("}");

        stream.println("    subgraph {\n"
                       "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
                );
        foreach (v; vertices!A)
            stream.printfln(`        "%s";`, v);
        stream.println("    }");

        stream.println("    subgraph {\n"
                       "        node [shape=box, fillcolor=gray91, style=filled];"
                );
        foreach (v; vertices!B)
            stream.printfln(`        "%s";`, v);
        stream.println("    }");

        // Draw the edges from A -> B
        foreach (edge; edges!(A, B))
            stream.printfln(`    "%s" -> "%s";`, edge.from, edge.to);

        // Draw the edges from B -> A
        foreach (edge; edges!(B, A))
            stream.printfln(`    "%s" -> "%s";`, edge.from, edge.to);
    }
}

unittest
{
    import std.stdio;

    auto g = G();
    g.put(X(1));
    g.put(Y(1));
    g.put(X(1), Y(1), 42);

    auto g2 = g.subgraph([X(1)], [Y(1)]);
    assert(g2.length!X == 1);
    assert(g2.length!Y == 1);
}

unittest
{
    import std.algorithm.comparison : equal;
    import change;
    import io;

    alias C = Change;

    auto g1 = G();
    g1.put(X(1));
    g1.put(X(2));
    g1.put(Y(1));
    g1.put(X(1), Y(1), 100);
    g1.put(X(2), Y(1), 200);

    auto g2 = G();
    g2.put(X(1));
    g2.put(X(3));
    g2.put(Y(1));
    g2.put(Y(2));
    g2.put(X(1), Y(1), 101);

    assert(g1.diffVertices!X(g2).equal([
        C!X(X(1), ChangeType.none),
        C!X(X(2), ChangeType.removed),
        C!X(X(3), ChangeType.added),
    ]));

    assert(g1.diffVertices!Y(g2).equal([
        C!Y(Y(1), ChangeType.none),
        C!Y(Y(2), ChangeType.added),
    ]));

    alias E = G.Edge;

    assert(g1.diffEdges!(X, Y)(g2).equal([
        C!(E!(X, Y))(E!(X, Y)(X(1), Y(1), 100), ChangeType.removed),
        C!(E!(X, Y))(E!(X, Y)(X(1), Y(1), 101), ChangeType.added),
        C!(E!(X, Y))(E!(X, Y)(X(2), Y(1), 200), ChangeType.removed),
    ]));
}
