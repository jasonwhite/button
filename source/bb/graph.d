/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.graph;

/**
 * Stupid set implementation using an associative array.
 *
 * This data structure and more should REALLY be in the standard library.
 */
private struct Set(T)
{
    private int[T] _items;

    /**
     * Initialize with a list of items.
     */
    this(T[] items) pure
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
        Set!B[A] edgesA;
        Set!A[B] edgesB;

        // Uniform way of accessing nodes.
        alias edge(Node : A) = edgesA;
        alias edge(Node : B) = edgesB;
    }

    /**
     * Adds a node.
     */
    void add(Node)(Node node) pure
    {
        if (node !in edge!Node)
            edge!Node[node] = typeof(edge!Node[node])();
    }

    /**
     * Removes a node and all the incoming and outgoing edges associated with
     * it.
     */
    void remove(Node)(Node node) pure
    {
        edge!Node.remove(node);
    }

    /**
     * Adds an edge.
     */
    void add(From,To)(From from, To to) pure
    {
        if (auto p = from in edge!From)
            p.add(to);
        else
            edge!From[from] = typeof(edge!From[from])([to]);
    }

    /**
     * Removes an edge.
     */
    void remove(From, To)(From from, To to) pure
    {
        edge!From[from].remove(to);
    }

    /**
     * Returns a range of nodes.
     */
    auto nodes(Node)() const pure
    {
        return edge!Node.byKey;
    }

    /**
     * Returns a range of outgoing edges from the given node.
     */
    auto outgoing(Node)(Node node) const pure
    {
        return edge!Node[node].items;
    }

    /**
     * Creates a subgraph using the given roots. This is done by traversing the
     * graph and only adding the nodes and edges that we come across.
     *
     * TODO: Simplify and parallelize this.
     */
    typeof(this) subgraph(const(A[]) rootsA, const(B[]) rootsB) const pure
    {
        // Keep track of which nodes have been visited.
        auto visitedA = Set!A();
        auto visitedB = Set!B();

        // Create an empty graph.
        auto g = typeof(return)();

        // List of nodes queued to be processed. Nodes in the queue do not
        // depend on each other, and thus, can be visited in parallel.
        A[] queuedA;
        B[] queuedB;

        // Queue the roots
        foreach (node; rootsA)
        {
            visitedA.add(node);
            queuedA ~= node;
        }

        foreach (node; rootsB)
        {
            visitedB.add(node);
            queuedB ~= node;
        }

        // Process both queues until they are empty.
        while (queuedA.length > 0 || queuedB.length > 0)
        {
            while (queuedA.length > 0)
            {
                // Pop off an item
                auto node = queuedA[$-1];
                queuedA.length -= 1;

                // Add the node to the subgraph
                g.add(node);

                // Add any children
                foreach (child; g.outgoing(node))
                {
                    if (child in visitedB) continue;

                    // Add the edge.
                    g.add(node, child);
                    visitedB.add(child);
                    queuedB ~= child;
                }
            }

            while (queuedB.length > 0)
            {
                // Pop off an item
                auto node = queuedB[$-1];
                queuedB.length -= 1;

                // Add the node to the subgraph
                g.add(node);

                // Add any children
                foreach (child; g.outgoing(node))
                {
                    if (child in visitedA) continue;

                    // Add the edge.
                    g.add(node, child);
                    visitedA.add(child);
                    queuedA ~= child;
                }
            }
        }

        return g;
    }
}

unittest
{
    import bb.index, bb.node;
    import io.text;

    auto g = Graph!(Index!Task, Index!Resource)();
    g.add(Index!Task(42));
    g.add(Index!Resource(42));
    g.add(Index!Resource(42), Index!Task(42));
    g.add(Index!Task(42), Index!Resource(42));

    foreach (node; g.outgoing(Index!Task(42)))
        println(node);
}
