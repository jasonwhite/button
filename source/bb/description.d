/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Build description.
 */
module bb.description;

import bb.rule, bb.vertex, bb.change, bb.state;
import multiset;
import std.typecons : Tuple, tuple;
import std.array : Appender;

/**
 * Reads a build description.
 */
struct BuildDescription
{
    private
    {
        // Vertices
        Appender!(Resource.Id[]) resources;
        Appender!(Task.Id[]) tasks;

        // Edges
        Appender!(Tuple!(Resource.Id, Task.Id)[]) edgesRT; // Resource -> Task
        Appender!(Tuple!(Task.Id, Resource.Id)[]) edgesTR; // Task -> Resource
    }

    this()(auto ref Rules rules) pure
    {
        foreach (rule; rules)
            addRule(rule);

        // TODO: Sort arrays.
    }

    this(BuildState state) pure
    {
        //add(state);

        // TODO: Sort arrays.
    }

    /**
     * Adds a single rule.
     */
    void addRule()(auto ref Rule rule)
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
    auto diff(const ref BuildDescription rhs) const pure
    {
        import std.algorithm : sort, uniq;
        import std.array : array;
        import std.typecons : tuple;

        return tuple(
            changes(this.resources.data.uniq, rhs.resources.data.uniq),
            changes(this.tasks.data.uniq, rhs.tasks.data.uniq),
            changes(this.edgesRT.data.uniq, rhs.edgesRT.data.uniq),
            changes(this.edgesTR.data.uniq, rhs.edgesTR.data.uniq)
            );
    }
}
