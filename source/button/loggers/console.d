/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * General logging of events to the console.
 */
module button.loggers.console;

import core.time : Duration;

import io.file.stream;
import io.text;

import button.events;
import button.task;
import button.state;
import button.textcolor : TextColor;

final class ConsoleLogger : Events
{
    private
    {
        import std.range : Appender;

        // Console streams to write to.
        File stdout;
        File stderr;

        // True if output should be verbose.
        bool verbose;

        TextColor color;

        // List of current task output. There is one appender per worker in the
        // thread pool.
        Appender!(ubyte[])[] output;
    }

    this(File stdout, File stderr, bool verbose, size_t poolSize)
    {
        this.stdout = stdout;
        this.stderr = stderr;
        this.verbose = verbose;
        this.color = TextColor(true);

        // The +1 is to accommodate index 0 which is used for threads not in the
        // pool.
        this.output.length = poolSize + 1;
    }

    void buildStarted()
    {
    }

    void buildSucceeded(Duration duration)
    {
    }

    void buildFailed(Duration duration, Exception e)
    {
    }

    void taskStarted(size_t worker, const ref Task task)
    {
        output[worker].clear();
    }

    private void printTaskOutput(size_t worker)
    {
        auto data = output[worker].data;

        stdout.write(data);

        if (data.length > 0 && data[$-1] != '\n')
            stdout.print("⏎\n");
    }

    private void printTaskTail(size_t worker, Duration duration)
    {
        import core.time : Duration;

        if (verbose)
        {
            stdout.println(color.status, "   ➥ Time taken: ", color.reset,
                    cast(Duration)duration);
        }
    }

    void taskSucceeded(size_t worker, const ref Task task,
            Duration duration)
    {
        synchronized (this)
        {
            stdout.println(color.status, " > ", color.reset,
                    task.toPrettyString(verbose));

            printTaskOutput(worker);
            printTaskTail(worker, duration);
        }
    }

    void taskFailed(size_t worker, const ref Task task, Duration duration,
            const Exception e)
    {
        import std.string : wrap;

        synchronized (this)
        {
            stdout.println(color.status, " > ", color.error,
                    task.toPrettyString(verbose), color.reset);

            printTaskOutput(worker);
            printTaskTail(worker, duration);

            enum indent = "             ";

            stdout.print(color.status, "   ➥ ", color.error, "Error: ",
                    color.reset, wrap(e.msg, 80, "", indent, 4));
        }
    }

    void taskOutput(size_t worker, in ubyte[] chunk)
    {
        output[worker].put(chunk);
    }
}
