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
 * Bipartite task graph.
 *
 * Resource nodes have edges to tasks. Task nodes have edges to resources.
 */
struct TaskGraph
{
    private
    {
        // Stores the index for the given node identifier.
        NodeIndex[ResourceId] resourceIndices;
        NodeIndex[TaskId] taskIndices;

        // TODO: Make the following appenders?

        // Stores the values of the nodes
        Resource[] resourceValues;
        Task[] taskValues;

        // TODO: Make list of edges a set.

        // Resource -> Task[] edges
        NodeIndex[][] resourceEdges;

        // Task -> Resource[] edges
        NodeIndex[][] taskEdges;
    }

    alias NodeIndex = size_t;

    enum InvalidNodeIndex = NodeIndex.max;

    // Resource -> Task[]
    Task[][ResourceId] resources;

    // Task -> Resource[]
    Resource[][TaskId] tasks;

    /**
     * Get the value of a task node by id.
     *
     * TODO: Return a reference instead.
     *
     * Returns a pointer to the node's value or null if it does not exist.
     */
    Task* getTask(TaskId id)
    {
        if (auto index = id in taskIndices)
            return getTask(*index);
        else
            return null;
    }

    // Ditto
    Task* getTask(NodeIndex index)
    {
        if (index < taskValues.length)
            return &taskValues[index];
        else
            return null;
    }

    /**
     * Gets the value of a resource node by id.
     */
    Resource* getResource(ResourceId id)
    {
        if (auto index = id in resourceIndices)
            return getResource(*index);
        else
            return null;
    }

    /// Ditto
    Resource* getResource(NodeIndex index)
    {
        if (index < resourceValues.length)
            return &resourceValues[index];
        else
            return null;
    }

    /**
     * Finds a node in the list and returns it's index. If the node is not in
     * the list, $(D InvalidNodeIndex) is returned.
     */
    NodeIndex findNode(TaskId id)
    {
        if (auto index = id in taskIndices)
            return *index;
        else
            return InvalidNodeIndex;
    }

    /// Ditto
    NodeIndex findResource(ResourceId id)
    {
        if (auto index = id in resourceIndices)
            return *index;
        else
            return InvalidNodeIndex;
    }

    /**
     * Adds a node to the list.
     *
     * Returns: The index of that node.
     */
    NodeIndex addNode(Task task)
    {
        if (auto index = task.command in taskIndices)
            return *index;

        NodeIndex i = taskValues.length;
        taskValues ~= task;
        taskIndices[task.command] = i;
        ++taskEdges.length;
        return i;
    }

    /// Ditto
    NodeIndex addNode(Resource resource)
    {
        if (auto index = resource.path in resourceIndices)
            return *index;

        NodeIndex i = resourceValues.length;
        resourceValues ~= resource;
        resourceIndices[resource.path] = i;
        resourceEdges ~= [];
        ++resourceEdges.length;
        return i;
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
     * TODO: Throw an error if a resource has >1 parent.
     */
    void addRule()(auto ref Rule rule)
    {
        // Add task to the graph
        auto taskIndex = addNode(rule.task);

        // Add edges to task
        foreach (input; rule.inputs)
        {
            // TODO: Check for duplicate edges
            resourceEdges[addNode(input)] ~= taskIndex;
        }

        // Add edges from task
        foreach (output; rule.outputs)
        {
            // TODO: Check for duplicate edges
            taskEdges[taskIndex] ~= addNode(output);
        }
    }

    /**
     * Generate a graph for GraphViz
     */
    void display(Stream)(Stream stream)
        if (isSink!Stream)
    {
        import io;
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
        foreach (i, edges; resourceEdges)
            foreach (j; edges)
                stream.printfln(`    "%s" -> "%s";`, *getResource(i), *getTask(j));

        // Draw the edges from tasks to outputs
        foreach (i, edges; taskEdges)
            foreach (j; edges)
                stream.printfln(`    "%s" -> "%s";`, *getTask(i), *getResource(j));
    }

    /**
     * Returns a range that iterates over the tasks in the graph. Tasks are
     * returned in groups that can be executed in parallel.
     */
    void traverse(alias fn)(const Resource[] changed)
    {
    }
}
