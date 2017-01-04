/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Classes for receiving events from the build system. This is the general
 * mechanism through which information is logged.
 */
module button.events;

import button.task;
import button.state;
import core.time : TickDuration;

/**
 * Interface for handling build system events. This can be used for logging or
 * visualization purposes.
 *
 * Examples of what can be done with this include:
 *  - Showing build progress in the terminal.
 *  - Generating a JSON log file to be analyzed later.
 *  - Sending events to a web interface for visualization.
 *  - Generating a Gantt chart of task durations to see critical paths.
 */
interface Events
{
    /**
     * Called when a build has started.
     */
    void buildStarted();

    /**
     * Called when a build has completed successfully.
     */
    void buildSucceeded(TickDuration duration);

    /**
     * Called when a build has failed with the exception that was thrown.
     */
    void buildFailed(TickDuration duration, Exception e);

    /**
     * Called when a task has started. Returns a new event handler for tasks.
     *
     * Parameters:
     *   worker = The node on which the task is running. This is guaranteed to
     *   be between 0 and the size of the task pool.
     *   task = The task itself.
     */
    void taskStarted(size_t worker, const ref Task task);

    /**
     * Called when a task has completed successfully.
     */
    void taskSucceeded(size_t worker, const ref Task task,
            TickDuration duration);

    /**
     * Called when a task has failed.
     */
    void taskFailed(size_t worker, const ref Task task, TickDuration duration,
            const Exception e);

    /**
     * Called when a chunk of output is received from the task.
     */
    void taskOutput(size_t worker, in ubyte[] chunk);
}
