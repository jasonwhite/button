[buildbadge]: https://travis-ci.org/jasonwhite/brilliant-build.svg?branch=master
[buildstatus]: https://travis-ci.org/jasonwhite/brilliant-build

# Brilliant Build [![Build Status][buildbadge]][buildstatus]

*This is a work in progress.*

A build system that aims to be correct, scalable, elegantly simple, and robust.

## "Ugh! Another build system? [Why?!][relevant xkcd]"

[relevant xkcd]: https://xkcd.com/927/

There are many, *many* other build systems out there. Almost all of them make
grand claims that they are better than all the rest. However, a single victor
has yet to emerge. Rest assured, no grand claims of superiority will be made
here. Time will tell if Brilliant Build is the One True Build System™ or not.

Most build systems tend to suffer from one or more of the following problems:

 1. They don't do correct incremental builds 100% of the time.
 2. They don't correctly track changes to the build description.
 3. They don't scale well with large projects (100,000+ source files).
 4. They are language-specific or aren't general enough to be widely used
    outside of a niche community.
 5. They are tied to a domain specific language.

I hypothesize that the reason no single build system has been widely successful
is because of problem #5. There is a huge number of projects that use Make or
Visual Studio to build. Nobody wants to rewrite these build descriptions for the
hot new build system on the block, nor should they when the advantages are not
worth the cost of translation. Instead, it would be preferable to use these
legacy build descriptions with a new build system.

Brilliant Build is designed such that it can simultaneously solve all of these
problems. Read on to find out how.

## Features

 * Fast and correct incremental builds.
 * Very general. Does not make any assumptions about the structure of your
   project.
 * Detects and displays cyclic dependencies.
 * Detects race conditions (i.e., when multiple tasks output to the same file).
 * Deletes output files that no longer get built.
 * Can generate a build description as part of the build.

## Quick Example

### Build Description

Here is a simple example of a build description:

```json
[
    {
        "inputs": ["foo.c", "baz.h"],
        "task": ["gcc", "-c", "foo.c", "-o", "foo.o"],
        "outputs": ["foo.o"]
    },
    {
        "inputs": ["bar.c", "baz.h"],
        "task": ["gcc", "-c", "bar.c", "-o", "bar.o"],
        "outputs": ["bar.o"]
    },
    {
        "inputs": ["foo.o", "bar.o"],
        "task": ["gcc", "foo.o", "bar.o", "-o", "foobar"],
        "outputs": ["foobar"]
    }
]
```

### "Ugh! JSON is a terrible language for a build description!"

Before you get your knickers in a knot, a build description like the one above
is not intended to be written by hand. Think of the above JSON file as the
fundamental machine language of the build system. Like x86 assembly, you almost
never want to write your fundamental build description by hand. It is simply far
too verbose and unmanageable. Instead, as part of the build process, the build
description is generated. In this recursive fashion, the scripts that generate
the build description have their own dependencies just as any build task does.
If those dependencies change, the build description is regenerated and fed back
into the build system for execution.

Generating the fundamental build description has several advantages:

 * The generator can be written in any language (even x86 assembly, if you're a
   masochist). By default, Brilliant Build comes with a tool to generate build
   descriptions with Lua scripts.
 * It cleanly separates configuration and execution. The generator takes care of
   configuration while the build system takes care of executing build tasks.
 * Build descriptions from other build systems can be automatically converted.
   For example, theoretically `Makefile`s or Visual Studio projects can be
   converted on the fly. This can greatly aid in migrating away from other
   inferior, yet widely used, build systems that are used in large, complex
   projects.
 * Since it is simple JSON, the generated build description can be easily parsed
   by other tools (e.g., IDEs) for analysis.

Thus, JSON is the *perfect* language for a build description.

### Generating the build description

Since no one wants to write JSON by hand, the above build description can be
generated using Lua:

```lua
local cc = require "rules.cc"

cc.binary {
    name = "foobar",
    srcs = {"foo.c", "bar.c"},
}
```

If this script is named `BUILD.lua`, we can generate the build description by
running
```bash
$ bblua BUILD.lua -o bb.json
```

### Visualizing the Build

A visualization of the above build description can be generated using
[GraphViz][]:

```bash
$ bb graph --full | dot -Tpng > build_graph.png
```
![Simple Task Graph](/docs/examples/basic/build.png)

[GraphViz]: http://www.graphviz.org/

*Note*: If the build description above was named `bb.json`, there is no need to
specify its path on the command line. Otherwise, the path to the file can be
specified with the `-f` option.

### Running the Build

Suppose this is our first time running the build. In that case, we will see a
full build:

```bash
$ bb build
:: Build description changed. Syncing with the database...
:: Checking for changes...
 - Found 3 modified resource(s)
 - Found 3 pending task(s)
:: Building...
 > gcc -c foo.c -o foo.o
   ➥ Time taken: 93 ms, 85 μs, and 2 hnsecs
 > gcc -c bar.c -o bar.o
   ➥ Time taken: 93 ms, 79 μs, and 3 hnsecs
 > gcc foo.o bar.o -o foobar
   ➥ Time taken: 58 ms, 318 μs, and 6 hnsecs
:: Build succeeded
:: Total time taken: 177 ms, 995 μs, and 3 hnsecs
```

If we run it again immediately without changing any files, nothing will happen:

```bash
$ bb update
:: Checking for changes...
:: Nothing to do. Everything is up to date.
:: Total time taken: 3 ms, 804 μs, and 9 hnsecs
```

Now suppose we make a change to the file `foo.c` and run the build again. Only
the necessary tasks to bring the outputs up-to-date are executed:

```bash
$ echo "// Another comment" >> foo.c
$ bb build
:: Checking for changes...
 - Found 1 modified resource(s)
 - Found 0 pending task(s)
:: Building...
 > gcc -c foo.c -o foo.o
   ➥ Time taken: 31 ms, 579 μs, and 3 hnsecs
:: Build succeeded
:: Total time taken: 41 ms, 448 μs, and 3 hnsecs
```

Note that `gcc foo.o bar.o -o foobar` was not executed because its output
`foo.o` did not change. Indeed, all we did was add a comment. In such a case,
`gcc` will produce an identical object file.

A file is only determined to be changed if its last modification time changed
*and* its checksum changed. Thus, one source of overbuilding is eliminated.

## Building the Build System

 1. Get the dependencies:

     * [A D compiler][DMD]. Only DMD is ensured to work.
     * [DUB][]: A package manager for D.

 2. Get the source:

    ```bash
    git clone https://github.com/jasonwhite/brilliant-build.git
    ```

 3. Build it:

    ```bash
    dub build
    ```

There should now be an executable `bb` at the root of the repository. It is
completely self-contained. Put it in a directory that is on your `$PATH` and run
`bb help` to get started!

[DMD]: http://dlang.org/download.html
[DUB]: http://code.dlang.org/download

## Planned Features

All of the above is already implemented. Below gives rough details on what will
eventually be implemented in order of descending priority.

### Wrap common tools

Commonly used tools such as `gcc`, `dmd`, `javac`, `lualatex`, etc. should be
wrapped in order to provide accurate dependency information. As a fallback,
`LD_PRELOAD` or `strace` can be used to discover all possible inputs/outputs for
a task.

### File system monitoring

Since the set of input files is known, these can be monitored for changes. When
one such file changes, a build can be started automatically to bring the outputs
up to date. There should be one daemon per build description.

### Caching

Similar to what [Bazel][] and [Buck][] do, build outputs should be cached. This
helps solve two major problems:

 1. Brilliant Build has no explicit support for variants (e.g., a *debug* or
    *release* build). If one wants to switch between debug and release builds,
    the build description must be regenerated and, thus, the entire build graph
    is invalidated and triggers a new build. If build outputs are cached,
    switching between variants will copy the build outputs from the cache
    instead of building from scratch.
 2. If two machines both run the same build, a lot of work is duplicated. If
    both builds are adding cached outputs to a shared cache, there would be a
    50% cache hit rate on average between the two machines. As more machines are
    added, the average cache hit rate goes up.

This caching mechanism would be implemented as a simple REST service. Outputs
are keyed by the checksum of the task's resource dependencies, the task's
command string, and the output's file name. The contents of an output is
uploaded with an HTTP `POST` using the output's key. Similarly, an output is
retrieved with an HTTP `GET` using the output's key. A `404` error code should
be returned if it doesn't exist in the cache.

[Bazel]: http://bazel.io/
[Buck]: https://buckbuild.com/

### Thorough documentation

A website hosting documentation on all things related to building software. This
includes:

 * Starting build descriptions for certain types of projects
 * Fundamental concepts of a build system
 * Tutorials on various topics

### Web interface

A web interface for running and visualizing builds could be extremely useful. In
such an interface, one should be able to click a button to start and stop a
build. A graph of the build should be displayed and updated in real time. A
search function should be available for finding nodes in the graph. One should
also be able to "walk" the nodes in the graph. Clicking on a node should display
its `stderr` and `stdout` log.

### Tool to translate other build descriptions to this one

Since the JSON build description is very general, theoretically a build
description from another build system (e.g., Make, MSBuild) could be translated
automatically.

This would greatly aid in transitioning away from the build system currently in
use. It would also potentially allow one to glue together many disparate build
descriptions into one.

## Other Build Systems

The design of Brilliant Build learns from the successes and failures of many
other build systems. In no particular order, these include:

 * [Tup](http://gittup.org/tup/)
 * [Ninja](https://martine.github.io/ninja/)
 * [Redo](https://github.com/apenwarr/redo)
 * [Shake](http://shakebuild.com/)
 * [Bazel](http://bazel.io/)
 * [Buck](https://buckbuild.com/)
 * [Meson](http://mesonbuild.com/)

## License

[MIT License](/LICENSE.md)
