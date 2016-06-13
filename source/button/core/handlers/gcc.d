/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles running gcc processes.
 *
 * Inputs and outputs are detected by adding the -MMD option and parsing the
 * deps file that gcc produces.
 */
module button.core.handlers.gcc;

import button.core.log;
import button.core.resource;

import std.range.primitives : isInputRange, ElementEncodingType,
                              front, empty, popFront;

import std.traits : isSomeChar;

/**
 * Exception that is thrown on invalid GCC deps syntax.
 */
class MakeParserError : Exception
{
    this(string msg)
    {
        // TODO: Include line information?
        super(msg);
    }
}

/**
 * Helper function to escape a character.
 */
private C escapeChar(C)(C c)
    if (isSomeChar!C)
{
    switch (c)
    {
    case 't': return '\t';
    case 'v': return '\v';
    case 'r': return '\r';
    case 'n': return '\n';
    case 'b': return '\b';
    case 'f': return '\f';
    case '0': return '\0';
    default:  return c;
    }
}

/**
 * A single Make rule.
 */
struct MakeRule
{
    string target;
    string[] deps;
}

/**
 * An input range of Make rules.
 *
 * This parses a deps file that gcc produces. The file consists of simple Make
 * rules. Rules are separated by lines (discounting line continuations). Each
 * rule consists of a target file and its dependencies.
 */
struct MakeRules(Source)
    if (isInputRange!Source && isSomeChar!(ElementEncodingType!Source))
{
    private
    {
        import std.array : Appender;
        import std.traits : Unqual;

        alias C = Unqual!(ElementEncodingType!Source);

        Source source;
        bool _empty;
        MakeRule current;

        Appender!(C[]) buf;
    }

    this(Source source)
    {
        this.source = source;
        popFront();
    }

    @property
    bool empty() const pure nothrow
    {
        return _empty;
    }

    @property
    const(MakeRule) front() const pure nothrow
    {
        return current;
    }

    /**
     * Parses a single file name.
     */
    private string parseFileName()
    {
        import std.uni : isWhite;

        buf.clear();

        while (!source.empty)
        {
            immutable c = source.front;

            if (c == ':' || c.isWhite)
            {
                // ':' delimits a target.
                break;
            }
            else if (c == '\\')
            {
                // Skip past the '\\'
                source.popFront();
                if (source.empty)
                    break;

                immutable e = source.front;
                if (e == '\n')
                {
                    // Line continuation
                    source.popFront();
                }
                else
                {
                    buf.put(escapeChar(e));
                    source.popFront();
                }

                continue;
            }

            // Regular character
            buf.put(c);
            source.popFront();
        }

        return buf.data.idup;
    }

    /**
     * Skips spaces.
     */
    private void skipSpace()
    {
        import std.uni : isSpace;
        while (!source.empty && isSpace(source.front))
            source.popFront();
    }

    /**
     * Skips whitespace
     */
    private void skipWhite()
    {
        import std.uni : isWhite;
        while (!source.empty && isWhite(source.front))
            source.popFront();
    }

    /**
     * Parses the list of dependencies after the target.
     *
     * Returns: The list of dependencies.
     */
    private string[] parseDeps()
    {
        Appender!(string[]) deps;

        skipSpace();

        while (!source.empty)
        {
            // A new line delimits the dependency list
            if (source.front == '\n')
            {
                source.popFront();
                break;
            }

            auto dep = parseFileName();
            if (dep.length)
                deps.put(dep);

            if (!source.empty && source.front == ':')
                throw new MakeParserError("Unexpected ':'");

            skipSpace();
        }

        return deps.data;
    }

    /**
     * Parses a rule.
     */
    private MakeRule parseRule()
    {
        string target = parseFileName();
        if (target.empty)
            throw new MakeParserError("Empty target name");

        skipSpace();

        if (source.empty)
            throw new MakeParserError("Unexpected end of file");

        if (source.front != ':')
            throw new MakeParserError("Expected ':' after target name");

        source.popFront();

        // Parse dependency names
        auto deps = parseDeps();

        skipWhite();

        return MakeRule(target, deps);
    }

    void popFront()
    {
        skipWhite();

        if (source.empty)
        {
            _empty = true;
            return;
        }

        current = parseRule();
    }
}

/**
 * Convenience function for constructing a MakeRules range.
 */
MakeRules!Source makeRules(Source)(Source source)
    if (isInputRange!Source && isSomeChar!(ElementEncodingType!Source))
{
    return MakeRules!Source(source);
}

unittest
{
    import std.array : array;
    import std.exception : collectException;
    import std.algorithm.comparison : equal;

    static assert(isInputRange!(MakeRules!string));

    {
        auto rules = makeRules(
                "\n\nfoo.c : foo.h   \\\n   bar.h \\\n"
                );

        assert(rules.equal([
                MakeRule("foo.c", ["foo.h", "bar.h"]),
        ]));
    }

    {
        auto rules = makeRules(
                "foo.c : foo.h \\\n bar.h\n"~
                "   \nbar.c : bar.h\n"~
                "\n   \nbaz.c:\n"~
                "ba\\\nz.c: blah.h\n"~
                `foo\ bar: bing\ bang`
                );

        assert(rules.equal([
                MakeRule("foo.c", ["foo.h", "bar.h"]),
                MakeRule("bar.c", ["bar.h"]),
                MakeRule("baz.c", []),
                MakeRule("baz.c", ["blah.h"]),
                MakeRule("foo bar", ["bing bang"]),
        ]));
    }

    assert(collectException!MakeParserError(makeRules(
                "foo.c: foo.h: bar.h"
                ).array));
}

int execute(
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        TaskLogger logger
        )
{
    import std.file : remove;

    import io.file : File, tempFile, AutoDelete;
    import io.range : byBlock;

    import button.core.handlers.base : base = execute;

    // Create the temporary file for the dependencies.
    auto depsPath = tempFile(AutoDelete.no).path;
    scope (exit) remove(depsPath);

    // Tell gcc to write dependencies to our temporary file.
    args ~= ["-MMD", "-MF", depsPath];

    auto exitCode = base(args, workDir, inputs, outputs, logger);

    if (exitCode != 0)
        return exitCode;

    // TODO: Parse the command line arguments for -I and -o options.

    // Parse the dependencies
    auto deps = File(depsPath).byBlock!char;
    foreach (rule; makeRules(&deps))
    {
        outputs.put(rule.target);
        inputs.put(rule.deps);
    }

    return 0;
}
