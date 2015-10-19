# Brilliant Build

*This is a work in progress.*

A build system that aims to be correct, scalable, elegantly simple, and robust.

## "Ugh! Another build system? [Why?!][relevant xkcd]"

[relevant xkcd]: https://xkcd.com/927/

Because, of the hundreds of build systems out there, the vast majority of them
are pretty terrible. They tend to suffer from a common set of ailments:

 * They don't do correct incremental builds.
 * They don't correctly track changes to the build description.
 * They don't scale well with huge projects.
 * They are language-specific or aren't general enough.
 * They have a horrendous build description language (e.g., Make).

Brilliant Build is designed such that it can solve all of these problems.
However, time will tell if this is actually true in practice.

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

A build description like the one above is not intended to be written by hand.
Think of the above file as the fundamental machine language of the build system.
You almost never want to write your fundamental build description by hand. It is
simply far too verbose and unmanageable. Instead, as part of the build process,
the build description is generated. In this recursive fashion, the script(s)
that generate the build description have their own dependencies just as a build
task does. If those dependencies change, the build description is regenerated
and compared with the old build description to see what was added or removed.

Generating the build description has the added benefit of being able to write
your generator in any language you please. It is even possible to write tools to
automatically translate the build descriptions of other build systems to this
one. Theoretically, even a `Makefile` or Visual Studio project file could be
automatically converted. This can greatly aid in migrating away from another
(inferior) build system used in large, complex projects.

### Visualizing the Build

A visualization of the above build description can be generated using
[GraphViz][]:

```bash
$ bb graph --verbose | dot -Tpng > build_graph.png
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
$ bb update
 > gcc -c bar.c -o bar.o
 > gcc -c foo.c -o foo.o
 > gcc foo.o bar.o -o foobar
```

If we run it again immediately without changing any files, nothing will happen:

```bash
$ bb update
```

Now suppose we make a change to the file `foo.c` and run the build again. Only
the necessary tasks to bring the outputs up-to-date are executed:

```bash
$ echo "// Another comment" >> foo.c
$ bb update
 > gcc -c foo.c -o foo.o
```

Note that `gcc foo.o bar.o -o foobar` was not executed because its output
`foo.o` did not change. Indeed, all we did was add a comment. In such a case,
`gcc` will produce an identical object file.

Changes are determined by the checksum of a file's contents, not just its last
modification time. Thus, one source of overbuilding is eliminated.

## Building the Build System

 1. Get the dependencies:

     * [A D compiler][DMD]. Only DMD is ensured to work.
     * [DUB][]: A package manager for D.

 2. Get the source:

    ```bash
    git clone --recursive https://github.com/jasonwhite/brilliant-build.git
    ```

 3. Bootstrap:

    ```bash
    ./bootstrap
    ```

There should now be an executable `bb` at the root of the repository. It is
completely self-contained. Put it in a directory that is on your `$PATH` and run
`bb help` to get started!

[DMD]: http://dlang.org/download.html
[DUB]: http://code.dlang.org/download

## Planned Features

All of the above is already implemented. Below gives rough details on what will
eventually be implemented in order of descending priority.

### Automatic, implicit dependencies

Currently, there is no way to discover dependencies while the build is running.
Everything must be specified explicitly up front before any tasks are executed.

To achieve the discovery of implicit dependencies, the task that is running will
be able to send a list of inputs and outputs to Brilliant Build. Brilliant Build
will then add these to the build graph.

This means that "wrapper" tasks must be created for common programs such as
`gcc` to discover dependencies. It would also be possible to use `strace` as a
fallback to discover all possible file dependencies.

### Convenient way to generate build descriptions

Currently, the JSON build description must be written by hand. This should
almost never be necessary. The build description should always be generated by
some other program.

The idea is to write libraries in one or more scripting languages (e.g., Lua and
Python) that help in generating the JSON build description.

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

### File system monitoring

Since the set of input files is known, these can be monitored for changes. When
one such file changes, a build can be started automatically to bring the outputs
up to date. There should be one daemon per build description.

### Tool to translate other build descriptions to this one

Since the JSON build description is very general, theoretically a build
description from another build system (e.g., Make, MSBuild) could be translated
automatically.

This would greatly aid in transitioning away from the build system currently in
use. It would also potentially allow one to glue together many disparate build
descriptions into one.

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

## Inspiration

The design of Brilliant Build learns from and draws inspiration from several
other build systems:

 * [Tup](http://gittup.org/tup/)
 * [Ninja](https://martine.github.io/ninja/)
 * [Redo](https://github.com/apenwarr/redo)
 * [Shake](http://shakebuild.com/)
 * [Bazel](http://bazel.io/)
 * [Buck](https://buckbuild.com/)

## License

[MIT License](/LICENSE.md)
