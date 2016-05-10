/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * General logging of events.
 */
module button.log.file;

import core.time : TickDuration;

import button.log;
import button.vertex;
import button.state;

import io.file.stream;
import io.text;

final class FileLogger : Logger
{
    import button.textcolor : TextColor;

    private
    {
        // File stream to log to
        File file;

        // True if output should be verbose.
        bool verbose;

        TextColor color;
    }

    private final class FileTaskLogger : TaskLogger
    {
        private
        {
            import std.range : appender, Appender;

            Task task;
            Appender!(ubyte[]) _output;
        }

        this(Task task)
        {
            this.task = task;
            _output = appender!(ubyte[]);
        }

        void output(in ubyte[] chunk)
        {
            _output.put(chunk);
        }

        private void printOutput()
        {
            file.write(_output.data);

            // Ensure there is always a line separator after the output
            if (_output.data.length > 0 && _output.data[$-1] != '\n')
                file.print("⏎\n");
        }

        private void printTail(TickDuration duration)
        {
            import core.time : Duration;
            if (verbose)
                file.println(color.status, "   ➥ Time taken: ", color.reset,
                        cast(Duration)duration);
        }

        void succeeded(TickDuration duration)
        {
            synchronized (this.outer)
            {
                file.println(color.status, " > ", color.reset,
                        task.toString(verbose));

                printOutput();
                printTail(duration);
            }
        }

        void failed(TickDuration duration, TaskError e)
        {
            import std.string : wrap;

            synchronized (this.outer)
            {
                file.println(color.status, " > ", color.error,
                        task.toString(verbose), color.reset);

                printOutput();
                printTail(duration);

                enum indent = "                 ";

                file.print(color.status, "   ➥ ", color.error, "Task Error: ",
                        color.reset, wrap(e.msg, 80, "", indent, 4));
            }
        }
    }

    this(File file, bool verbose)
    {
        this.file = file;
        this.verbose = verbose;
        this.color = TextColor(true);
    }

    void buildStarted()
    {
    }

    void buildEnded(bool success, TickDuration duration)
    {
    }

    TaskLogger taskStarted(Index!Task index, Task task, bool dryRun)
    {
        return new FileTaskLogger(task);
    }
}
