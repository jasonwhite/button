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
        foreach (item; items)
            add(item);
    }

    /**
     * Adds a item to the set.
     */
    void add(T item) pure
    {
        _items[item] = typeof(_items[item]).init;
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
        // Incoming edges.
        Set!B[A] neighborsInA;
        Set!A[B] neighborsInB;

        // Outgoing edges.
        Set!B[A] neighborsOutA;
        Set!A[B] neighborsOutB;

        // Uniform way of accessing nodes.
        alias neighborsIn(Node : A) = neighborsInA;
        alias neighborsIn(Node : B) = neighborsInB;
        alias neighborsOut(Node : A) = neighborsOutA;
        alias neighborsOut(Node : B) = neighborsOutB;
    }

    invariant
    {
        assert(neighborsInA.length == neighborsOutA.length);
        assert(neighborsInB.length == neighborsOutB.length);
    }

    /**
     * Returns the number of nodes for the given type.
     */
    @property size_t length(Node)() const pure nothrow
    {
        return neighborsIn!Node.length;
    }

    /**
     * Adds a node.
     */
    void add(Node)(Node node) pure
    {
        if (node !in neighborsIn!Node)
            neighborsIn!Node[node] = typeof(neighborsIn!Node[node])();

        if (node !in neighborsOut!Node)
            neighborsOut!Node[node] = typeof(neighborsOut!Node[node])();
    }

    /**
     * Removes a node and all the incoming and outgoing edges associated with
     * it.
     */
    void remove(Node)(Node node) pure
    {
        neighborsIn!Node.remove(node);
        neighborsOut!Node.remove(node);
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
     * Adds an edge. Both nodes must be added to the graph first.
     */
    void add(From,To)(From from, To to) pure
    {
        auto incoming = to in neighborsIn!To;
        assert(incoming);
        incoming.add(from);

        auto outgoing = from in neighborsOut!From;
        assert(outgoing);
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
     * Returns a range of nodes.
     */
    auto nodes(Node)() const pure
    {
        return neighborsOut!Node.byKey;
    }

    /**
     * Returns a range of incoming edges to the given node.
     */
    auto incoming(Node)(Node node) const pure
    {
        return neighborsIn!Node[node].items;
    }

    /**
     * Returns a range of outgoing edges from the given node.
     */
    auto outgoing(Node)(Node node) const pure
    {
        return neighborsOut!Node[node].items;
    }

    /**
     * Number of incoming edges for the given node.
     */
    size_t degreeIncoming(Node)(Node node) const pure nothrow
    {
        return neighborsIn!Node[node].length;
    }

    /**
     * Number of outgoing edges for the given node.
     */
    size_t degreeOutgoing(Node)(Node node) const pure nothrow
    {
        return neighborsOut!Node[node].length;
    }

    /**
     * Creates a subgraph using the given roots. This is done by traversing the
     * graph and only adding the nodes and edges that we come across.
     *
     * TODO: Simplify and parallelize this.
     */
    typeof(this) subgraph(const(A[]) rootsA, const(B[]) rootsB) const pure
    {
        auto g = typeof(return)();

        // Keep track of which nodes have been visited.
        auto visitedA = Set!A(rootsA);
        auto visitedB = Set!B(rootsB);

        // List of nodes queued to be visited. Nodes in the queue do not depend
        // on each other, and thus, can be visited in parallel.
        A[] queueA = rootsA.dup;
        B[] queueB = rootsB.dup;

        // Process both queues until they are empty.
        while (queueA.length > 0 || queueB.length > 0)
        {
            while (queueA.length > 0)
            {
                // Pop off a node
                auto node = queueA[$-1];
                queueA.length -= 1;

                // Add the node
                g.add(node);

                // Add any children
                foreach (child; g.outgoing(node))
                {
                    if (child in visitedB) continue;

                    // Add the edge.
                    g.add(node, child);
                    visitedB.add(child);
                    queueB ~= child;
                }
            }

            while (queueB.length > 0)
            {
                // Pop off a node
                auto node = queueB[$-1];
                queueB.length -= 1;

                // Add the node
                g.add(node);

                // Add any children
                foreach (child; g.outgoing(node))
                {
                    if (child in visitedA) continue;

                    // Add the edge.
                    g.add(node, child);
                    visitedA.add(child);
                    queueA ~= child;
                }
            }
        }

        return g;
    }
}
