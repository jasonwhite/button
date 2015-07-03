/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Build description.
 */
module bb.description;

import change, multiset;
import bb.rule, bb.vertex, bb.state;
import std.typecons : Tuple, tuple;
import std.range : ElementType;

/**
 * Reads a build description.
 */
struct BuildDescription
{
    private
    {
        import std.array : Appender;

        // Vertices
        Appender!(ResourceId[]) resources;
        Appender!(TaskId[]) tasks;

        // Edges
        Appender!(Tuple!(ResourceId, TaskId)[]) edgesRT; // Resource -> Task
        Appender!(Tuple!(TaskId, ResourceId)[]) edgesTR; // Task -> Resource
    }

    this(R)(auto ref R rules) pure
        if (is(ElementType!R : const(Rule)))
    {
        import std.algorithm : sort;

        foreach (rule; rules)
            addRule(rule);

        sort(resources.data);
        sort(tasks.data);
        sort(edgesRT.data);
        sort(edgesTR.data);
    }

    this(BuildState state)
    {
        import std.algorithm : sort;

        // TODO: Add all nodes and edges.
        // TODO: Only add explicit edges.

        // Add all nodes.
        foreach (id; state.taskIdentifiers)
            tasks.put(id);
        foreach (id; state.resourceIdentifiers)
            resources.put(id);

        // Add all edges.
        //foreach (edge; state.resourceEdges)
            //edgesRT.put(tuple(edge.from, edge.to));

        //foreach (edge; state.taskEdges)
            //edgesTR.put(tuple(edge.from, edge.to));

        sort(resources.data);
        sort(tasks.data);
    }

    /**
     * Adds a single rule.
     */
    private void addRule()(auto const ref Rule rule)
    {
        tasks.put(rule.task);

        foreach (input; rule.inputs)
        {
            resources.put(input);
            edgesRT.put(tuple(input, rule.task));
        }

        foreach (output; rule.outputs)
        {
            resources.put(output);
            edgesTR.put(tuple(rule.task, output));
        }
    }

    /**
     * Returns the differences between this build description and another.
     */
    auto diff()(auto ref BuildDescription rhs) pure
    {
        import std.algorithm : uniq, filter;
        import std.array : array;
        import std.typecons : tuple;

        return tuple(
            changes(this.resources.data.uniq, rhs.resources.data.uniq).filter!(c => c.type != ChangeType.none),
            changes(this.tasks.data.uniq, rhs.tasks.data.uniq).filter!(c => c.type != ChangeType.none),
            changes(this.edgesRT.data.uniq, rhs.edgesRT.data.uniq).filter!(c => c.type != ChangeType.none),
            changes(this.edgesTR.data.uniq, rhs.edgesTR.data.uniq).filter!(c => c.type != ChangeType.none)
            );
    }
}

unittest
{
    immutable Rule[] rulesA = [
        {
            inputs: ["foo.c", "baz.h"],
            task: ["gcc", "-c", "foo.c", "-o", "foo.o"],
            outputs: ["foo.o"]
        },
        {
            inputs: ["bar.c", "baz.h"],
            task: ["gcc", "-c", "bar.c", "-o", "bar.o"],
            outputs: ["bar.o"]
        },
        {
            inputs: ["foo.o", "bar.o"],
            task: ["gcc", "foo.o", "bar.o", "-o", "foobar"],
            outputs: ["foobar"]
        },
    ];

    immutable Rule[] rulesB = [
        {
            inputs: ["foo.c", "baz.h"],
            task: ["gcc", "-c", "foo.c", "-o", "foo.o"],
            outputs: ["foo.o"]
        },
        {
            inputs: ["bar.c", "baz.h"],
            task: ["gcc", "-c", "bar.c", "-o", "bar.o"],
            outputs: ["bar.o"]
        },
    ];

    import io;

    auto diff = BuildDescription(rulesA).diff(BuildDescription(rulesB));

    println("Resource diff: ", diff[0]);
    println("Task diff:     ", diff[1]);
    println("RT diff:       ", diff[2]);
    println("TR diff:       ", diff[3]);
}
