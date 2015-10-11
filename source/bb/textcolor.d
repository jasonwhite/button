/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Helper module for colorizing terminal output.
 */
module bb.textcolor;

/*
 * Black        0;30     Dark Gray     1;30
 * Red          0;31     Light Red     1;31
 * Green        0;32     Light Green   1;32
 * Brown/Orange 0;33     Yellow        1;33
 * Blue         0;34     Light Blue    1;34
 * Purple       0;35     Light Purple  1;35
 * Cyan         0;36     Light Cyan    1;36
 * Light Gray   0;37     White         1;37
*/

private
{
    immutable black     = "\033[0;30m", boldBlack     = "\033[1;30m",
              red       = "\033[0;31m", boldRed       = "\033[1;31m",
              green     = "\033[0;32m", boldGreen     = "\033[1;32m",
              orange    = "\033[0;33m", boldOrange    = "\033[1;33m",
              blue      = "\033[0;34m", boldBlue      = "\033[1;34m",
              purple    = "\033[0;35m", boldPurple    = "\033[1;35m",
              cyan      = "\033[0;36m", boldCyan      = "\033[1;36m",
              lightGray = "\033[0;37m", boldLightGray = "\033[1;37m";

    immutable bold  = "\033[1m";
    immutable reset = "\033[0m";

    immutable success = boldGreen;
    immutable error   = boldRed;
    immutable warning = boldOrange;
    immutable status  = blue;
}

struct TextColor
{
    private bool _enabled;

    this(bool enabled)
    {
        _enabled = enabled;
    }

    @property
    immutable(string) opDispatch(string name)() const pure nothrow
    {
        if (!_enabled)
            return "";

        return mixin(name);
    }
}

/**
 * Returns true if the output is capable of being colorized.
 */
version (Windows)
{
    enum colorizable = false;
}
else
{
    bool colorizable()
    {
        import io.file.stdio : stdout;
        return stdout.isTerminal;
    }
}

/**
 * Returns true if the output should be colored based on the given option.
 */
bool colorOutput(string option)
{
    switch (option)
    {
        case "always":
            return true;
        case "never":
            return false;
        default:
            return colorizable;
    }
}
