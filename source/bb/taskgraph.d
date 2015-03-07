/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jason White
 */
module bb.taskgraph;

import bb.rule;

import io.stream.types : isSink;

import bb.resource, bb.task;

/**
 */
class TaskGraphException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

/**
 * Bipartite task graph.
 *
 * Resource nodes have edges to tasks. Task nodes have edges to resources.
 */
struct TaskGraph
{
    private
    {
        // Stores the index for the given node identifier.
        Index!Resource[Resource.Name] resourceIndices;
        Index!Task[Task.Name] taskIndices;

        // TODO: Make the following appenders?

        // Stores the values of the nodes
        Resource[] resourceValues;
        Task[] taskValues;

        // TODO: Make list of edges a set to avoid duplicate edges.

        // Resource -> Task[] edges
        Index!Task[][] resourceEdges;

        // Task -> Resource[] edges
        Index!Resource[][] taskEdges;
    }

    // Index into a node. We use this to avoid mixing the usage of a resource
    // index with a task index.
    struct Index(Node)
    {
        size_t index;
        alias index this;

        enum Invalid = size_t.max;
    }

    enum InvalidNodeIndex = size_t.max;

    /**
     * Gets a node's index by its name.
     */
    Index!Node getIndex(Node)(Node.Name name)
        if (is(Node == Task))
    {
        return taskIndices[name];
    }

    /// Ditto
    Index!Node getIndex(Node)(Node.Name name)
        if (is(Node == Resource))
    {
        return resourceIndices[name];
    }

    /**
     * Gets the value of a task node.
     */
    ref Node getValue(Node)(const Node.Name name)
    {
        return getValue(getIndex(name));
    }

    /// Ditto
    ref Task getValue(Index!Task index)
    {
        return taskValues[index];
    }

    /// Ditto
    ref Resource getValue(Index!Resource index)
    {
        return resourceValues[index];
    }

    /**
     * Finds a node in the list and returns it's index. If the node is not in
     * the list, $(D InvalidNodeIndex) is returned.
     */
    Index!Task findNode(const Task.Name id)
    {
        if (auto index = id in taskIndices)
            return *index;
        else
            return Index!Task(InvalidNodeIndex);
    }

    /// Ditto
    Index!Resource findNode(const Resource.Name id)
    {
        if (auto index = id in resourceIndices)
            return *index;
        else
            return Index!Resource(InvalidNodeIndex);
    }

    /**
     * Adds a node to the list.
     *
     * Returns: The index of that node.
     */
    Index!Resource addNode(Resource resource)
    {
        if (auto index = resource.path in resourceIndices)
            return *index;

        auto i = Index!Resource(resourceValues.length);
        resourceValues ~= resource;
        resourceIndices[resource.path] = i;
        resourceEdges ~= [];
        ++resourceEdges.length;
        return i;
    }

    /// Ditto
    Index!Task addNode(Task task)
    {
        if (auto index = task.command in taskIndices)
            return *index;

        auto i = Index!Task(taskValues.length);
        taskValues ~= task;
        taskIndices[task.command] = i;
        ++taskEdges.length;
        return i;
    }

    /**
     * Adds an edge.
     */
    void addEdge(const Index!Resource from, const Index!Task to)
    {
        // TODO: Use a set to avoid duplicates
        resourceEdges[from] ~= to;
    }

    /// Ditto
    void addEdge(const Index!Task from, const Index!Resource to)
    {
        // TODO: Use a set to avoid duplicates
        taskEdges[from] ~= to;

        // Increment the number of incoming edges to the resource
        if (++getValue(to).incoming > 1)
            throw new TaskGraphException("Resource '"~ getValue(to).path ~ "' is an output of multiple tasks.");
    }

    /**
     * Gets the outgoing edges from the given node.
     *
     * Throws an exception if the node does not exist.
     */
    const(Index!Task[][]) getEdges(Node : Resource)()
    {
        return resourceEdges;
    }

    const(Index!Resource[][]) getEdges(Node : Task)()
    {
        return taskEdges;
    }

    const(Index!Task[]) getEdges(const Index!Resource index)
    {
        return resourceEdges[index];
    }

    /// Ditto
    const(Index!Resource[]) getEdges(const Index!Task index)
    {
        return taskEdges[index];
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
     *
     * TODO: Move this into a separate class/struct?
     */
    void addRule()(auto ref Rule rule)
    {
        // TODO: Throw a more informative exception.
        if (findNode(rule.task.command) != InvalidNodeIndex)
            throw new Exception("Duplicate task.");

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
     * Generate a graph for GraphViz
     *
     * TODO: Move this into a separate class/struct?
     */
    void display(Stream)(Stream stream)
        if (isSink!Stream)
    {
        import io.text;
        stream.println("digraph G {");
        scope (success) stream.println("}");

        // Style the tasks
        stream.println("    // Tasks\n"
                       "    subgraph {\n"
                       "        node [shape=box, fillcolor=gray91, style=filled];"
                );
        foreach (task; taskValues)
            stream.printfln(`        "%s";`, task);
        stream.println("    }");

        // Style the Resources
        stream.println("    // Resources\n"
                       "    subgraph {\n"
                       "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
                );
        foreach (resource; resourceValues)
            stream.printfln(`        "%s";`, resource);
        stream.println("    }");

        // Draw the edges from inputs to tasks
        foreach (i, edges; getEdges!Resource())
            foreach (j; edges)
                stream.printfln(`    "%s" -> "%s";`, getValue(Index!Resource(i)), getValue(Index!Task(j)));

        // Draw the edges from tasks to outputs
        foreach (i, edges; getEdges!Task())
            foreach (j; edges)
                stream.printfln(`    "%s" -> "%s";`, getValue(Index!Task(i)), getValue(Index!Resource(j)));
    }

    /**
     * Traverses the graph starting with a set of changed nodes.
     *
     * TODO: Move this into a separate class/struct?
     */
    void traverse(alias fn)(const Resource[] changed)
    {
        // List of nodes queued to be processed. Nodes in a queue do not depend
        // on each other, and thus, can be processed/visited in parallel.
        Index!Resource[] queuedResources;
        Index!Task[] queuedTasks;
    }
}
