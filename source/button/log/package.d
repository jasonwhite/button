/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * General logging of events.
 */
module button.log;

import button.vertex;
import button.state;
import core.time : TickDuration;

interface Logger
{
    /**
     * The build has started.
     */
    void buildStarted();

    /**
     * The build has ended.
     */
    void buildEnded(bool success, TickDuration duration);

    /**
     * Called when a task has started and returns a new task logger.
     */
    TaskLogger taskStarted(Index!Task index, Task task, bool dryRun);
}

interface TaskLogger
{
    /**
     * Called when a chunk of output is received from the task.
     */
    void output(in ubyte[] chunk);

    /**
     * Called when the task has failed. There will be no more output events
     * after this.
     */
    void failed(TickDuration duration, TaskError e);

    /**
     * Called when the task has completed successfully. There will be no more
     * output events after this.
     */
    void succeeded(TickDuration duration);
}
