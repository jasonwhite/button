/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.taskgraph;

import bb.rule;

import io.stream.types : isSink;

import bb.index, bb.node;

/**
 * Bipartite task graph.
 */
struct TaskGraph
{
    private
    {
        /**
         * Bookkeeping information.
         */
        struct Edges(Node)
        {
            /**
             * Outgoing edges.
             */
            Index!Node[] outgoing;

            /**
             * Number of incoming edges.
             */
            size_t incoming;
        }

        // Stores the index for the given node identifier.
        Index!Resource[Resource.Identifier] resourceIndices;
        Index!Task[Task.Identifier] taskIndices;

        // Stores the data relating to nodes.
        Resource[] resources;
        Task[] tasks;

        // Edge information.
        Edges!Task[] resourceEdges;
        Edges!Resource[] taskEdges;
    }

    enum InvalidIndex = size_t.max;

    enum isNode(Node) = is(Node : Resource) || is(Node : Task);

    /**
     * Returns the index for the node with the given identifier.
     */
    Index!Node getIndex(Node)(Node.Identifier id)
        if (isNode!Node)
    {
        static if (is(Node : Resource))
            return resourceIndices[id];
        else static if (is(Node : Task))
            return taskIndices[id];
    }

    /**
     * Returns a list of nodes and their data.
     */
    inout(Node[]) getNodes(Node)() inout
        if (isNode!Node)
    {
        static if (is(Node : Resource))
            return resources;
        else static if (is(Node : Task))
            return tasks;
    }

    /**
     * Returns a list of all the edges.
     */
    inout(Edges!Task[]) getEdges(Node : Resource)() inout
    {
        return resourceEdges;
    }

    /// Ditto
    inout(Edges!Resource[]) getEdges(Node : Task)() inout
    {
        return taskEdges;
    }

    /**
     * Returns a list of a node's edges.
     */
    auto getEdges(Node)(Index!Node index) const pure
        if (isNode!Node)
    {
        return getEdges!Node[index];
    }

    /**
     * Returns a node's data.
     */
    inout(Node*) getNode(Node)(Index!Node index) inout
    {
        return &getNodes!Node()[index];
    }

    /**
     * Adds a node to the list. This must be done before adding a node's edges.
     *
     * Returns the index to the new node, or one that already exists.
     */
    Index!Resource addNode(Resource resource)
    {
        if (auto index = resource.identifier in resourceIndices)
            return *index;

        auto index = Index!Resource(resources.length);
        resources ~= resource;
        resourceIndices[resource.identifier] = index;
        ++resourceEdges.length;
        return index;
    }

    /// Ditto
    Index!Task addNode(Task task)
    {
        if (auto index = task.identifier in taskIndices)
            return *index;

        auto index = Index!Task(tasks.length);
        tasks ~= task;
        taskIndices[task.identifier] = index;
        ++taskEdges.length;
        return index;
    }

    /**
     * Adds an edge from one node to the other.
     */
    void addEdge(Index!Resource from, Index!Task to)
    {
        // Don't add duplicate edges
        foreach (edge; getEdges(from).outgoing)
            if (edge == to) return; // Edge already added.

        resourceEdges[from].outgoing ~= to;
        ++taskEdges[to].incoming;
    }

    /// Ditto
    void addEdge(Index!Task from, Index!Resource to)
    {
        // Don't add duplicate edges
        foreach (edge; getEdges(from).outgoing)
            if (edge == to) return; // Edge already added.

        taskEdges[from].outgoing ~= to;
        if (++resourceEdges[to].incoming > 1)
            throw new Exception("Resource '"~ getNode(to).toString() ~ "' is an output of multiple tasks.");
    }

    /**
     * Adds a range of rules to the graph.
     */
    void addRules()(auto ref Rules rules)
    {
        foreach (rule; rules)
            addRule(rule);
    }

    /**
     * Adds a single rule to the graph.
     */
    void addRule()(auto ref Rule rule)
    {
        // TODO: Throw a more informative exception.
        //if (findNode(rule.task.command) != InvalidNodeIndex)
            //throw new Exception("Duplicate task.");

        // Add task to the graph
        auto taskIndex = addNode(rule.task);

        // Add edges to task
        foreach (input; rule.inputs)
            addEdge(addNode(input), taskIndex);

        // Add edges from task
        foreach (output; rule.outputs)
            addEdge(taskIndex, addNode(output));
    }

    /**
     * Generate input suitable for GraphViz.
     */
    void show(Stream)(Stream stream)
        if (isSink!Stream)
    {
        import io.text;
        stream.println("digraph G {");
        scope (success) stream.println("}");

        // Style the Resources
        stream.println("    // Resources\n"
                       "    subgraph {\n"
                       "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
                );
        foreach (resource; getNodes!Resource())
            stream.printfln(`        "%s";`, resource);
        stream.println("    }");

        // Style the tasks
        stream.println("    // Tasks\n"
                       "    subgraph {\n"
                       "        node [shape=box, fillcolor=gray91, style=filled];"
                );
        foreach (task; getNodes!Task())
            stream.printfln(`        "%s";`, task);
        stream.println("    }");

        // Draw the edges from inputs to tasks
        foreach (i, edges; getEdges!Resource)
            foreach (j; edges.outgoing)
                stream.printfln(`    "%s" -> "%s";`,
                        *getNode(Index!Resource(i)),
                        *getNode(Index!Task(j)));

        // Draw the edges from tasks to outputs
        foreach (i, edges; getEdges!Task)
            foreach (j; edges.outgoing)
                stream.printfln(`    "%s" -> "%s";`,
                        *getNode(Index!Task(i)),
                        *getNode(Index!Resource(j)));
    }

    /**
     * Creates a subgraph with the given roots. This is done by traversing the
     * graph and only adding the nodes and edges that we come across.
     *
     * TODO: Process queues in parallel.
     */
    typeof(this) subgraph(const(Index!Resource[]) resourceRoots,
                          const(Index!Task[]) taskRoots)
    {
        // Keep track of which nodes have been visited
        auto visitedResources = new bool[resources.length];
        auto visitedTasks = new bool[tasks.length];

        // Create an empty graph
        typeof(this) graph = typeof(this)();

        // List of nodes queued to be processed. Nodes in the queue do not
        // depend on each other, and thus, can be processed/visited in parallel.
        Index!Resource[] queuedResources;
        Index!Task[] queuedTasks;

        // Queue the resource roots
        foreach (index; resourceRoots)
        {
            visitedResources[index] = true;
            queuedResources ~= index;
        }

        // Queue the resource tasks
        foreach (index; taskRoots)
        {
            visitedTasks[index] = true;
            queuedTasks ~= index;
        }

        // Process both queues until they are empty
        while (queuedResources.length > 0 || queuedTasks.length > 0)
        {
            // Process queued resources
            while (queuedResources.length > 0)
            {
                // Pop off a resource
                auto index = queuedResources[$-1];
                queuedResources.length -= 1;

                // Add the node to the subgraph
                auto newIndex = graph.addNode(*getNode(index));

                // Add any children
                foreach (taskIndex; getEdges(index).outgoing)
                {
                    if (!visitedTasks[taskIndex])
                    {
                        // Add the edge
                        graph.addEdge(newIndex, graph.addNode(*getNode(taskIndex)));

                        visitedTasks[taskIndex] = true;
                        queuedTasks ~= taskIndex;
                    }
                }
            }

            // Process queued tasks
            while (queuedTasks.length > 0)
            {
                // Pop off a task
                auto index = queuedTasks[$-1];
                queuedTasks.length -= 1;

                // Add the node to the subgraph
                auto newIndex = graph.addNode(*getNode(index));

                // Add any children
                foreach (resourceIndex; getEdges(index).outgoing)
                {
                    if (!visitedResources[resourceIndex])
                    {
                        // Add the edge
                        graph.addEdge(newIndex, graph.addNode(*getNode(resourceIndex)));

                        visitedResources[resourceIndex] = true;
                        queuedResources ~= resourceIndex;
                    }
                }
            }
        }

        return graph;
    }

    /**
     * Updates the entire graph.
     *
     * TODO: Pass messages to worker threads instead of using a queue.
     */
    void update()
    {
        import io.text, io.file.stdio;

        // Keep track of which nodes have been visited
        auto visitedResources = new bool[resources.length];
        auto visitedTasks = new bool[tasks.length];

        // List of nodes queued to be processed. Nodes in the queue do not
        // depend on each other, and thus, can be processed/visited in parallel.
        Index!Resource[] queuedResources;
        Index!Task[] queuedTasks;

        // Start at the nodes with no incoming edges.

        // Queue the resource roots
        foreach (index, edges; resourceEdges)
        {
            if (edges.incoming == 0)
            {
                visitedResources[index] = true;
                queuedResources ~= Index!Resource(index);
            }
        }

        // Queue the task roots
        foreach (index, edges; taskEdges)
        {
            if (edges.incoming == 0)
            {
                visitedTasks[index] = true;
                queuedTasks ~= Index!Task(index);
            }
        }

        // Process both queues until they are empty
        while (queuedResources.length > 0 || queuedTasks.length > 0)
        {
            // Process queued resources
            while (queuedResources.length > 0)
            {
                // Pop off a resource
                auto index = queuedResources[$-1];
                queuedResources.length -= 1;

                // TODO: Call the function to process this edge.

                // Add any children
                foreach (taskIndex; getEdges(index).outgoing)
                {
                    if (!visitedTasks[taskIndex])
                    {
                        // Queue the task.
                        visitedTasks[taskIndex] = true;
                        queuedTasks ~= taskIndex;
                    }
                }
            }

            // Process queued tasks
            while (queuedTasks.length > 0)
            {
                // Pop off a task
                auto index = queuedTasks[$-1];
                queuedTasks.length -= 1;

                // TODO: Execute the task
                stderr.println(" > ", *getNode(index));

                // Add any children
                foreach (resourceIndex; getEdges(index).outgoing)
                {
                    if (!visitedResources[resourceIndex])
                    {
                        // Queue the resource
                        visitedResources[resourceIndex] = true;
                        queuedResources ~= resourceIndex;
                    }
                }
            }
        }
    }
}
