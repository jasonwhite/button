---
title: "Overview"
category: intro
order: 0
permalink: /:collection/
---

Brilliant Build is a very general, elegantly simple, and powerful build system.
This document gives a high-level overview of what Brilliant Build is, what it
can do, and how it works.

## Introduction

If you don't already know what a build system is, it is a tool to automate the
steps necessary to translate source code to deliverables. Well known tools in
this arena include:

 * [Make][], [MSBuild][]
 * [Ant][], [Maven][], [Gradle][]
 * [Bazel][], [Buck][], [Pants][]

It should be noted that Brilliant Build is *not* a project generator, package
manager, or continuous integration server. However, it is certainly an excellent
choice to build these things off of.

[Make]: https://www.gnu.org/software/make/
[MSBuild]: https://github.com/Microsoft/msbuild
[Ant]: http://ant.apache.org/
[Maven]: https://maven.apache.org/
[Gradle]: http://gradle.org/
[Bazel]: http://bazel.io/
[Buck]: https://buckbuild.com/
[Pants]: http://pantsbuild.github.io/

## Features

Brilliant Build has some pretty neat features:

 * Fast and correct incremental builds.
 * Implicit dependency detection.
 * Able to generate the build description as part of the build.
 * Can run builds automatically when something changes.

Because it is general enough to be able to build a project written in any
language, Brilliant Build is particularly useful for building multi-language
projects. Many build systems are tailored for a particular language. This can be
very good for single-language projects, but it can also become very restrictive.

## How It Works

In order to understand how Brilliant Build works, it is imperative to understand
at a high level its underlying data structure and how that data structure is
operated on.

### The Build Graph

At the heart of this build system is a bipartite directed acyclic graph:

![Build Graph]({{ site.baseurl }}/assets/img/build.png)

Lets just call this the *build graph* because the proper mathematical term is a
mouthful. The build graph is [bipartite][] because it can be partitioned into
two types of nodes: *resources* and *tasks*. In the figure above, the resources
and tasks are shown as ellipses and rectangles, respectively. A resource is some
file and a task is some program to execute. Resources are the inputs and outputs
of a task.

In order to build, we simply traverse the graph starting at the top and work our
way down while executing tasks. Of course, tasks that don't depend on each other
are executed in parallel. Furthermore, if a resource hasn't been modified, the
task it leads to will not be executed.

[bipartite]: https://en.wikipedia.org/wiki/Bipartite_graph

### The Build Description

The build graph is stored internally and created from the *build description*.
The build description is simply a JSON file containing a list of *rules*:

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

A rule consists of a list of inputs, a task, and a list of outputs. Connecting
these rules together forms the build graph as shown in the previous section.

When the build description is modified and we run the build again with `bb
update`, the internal build graph is incrementally updated with the changes. If
a rule is added to the build description, then it is added to the build graph
and the task is marked as "out of date" so that it gets unconditionally
executed. If, on the other hand, a rule is removed from the build description,
then it is removed from the build graph and all of its outputs are deleted from
the file system. This ensures there are no extraneous files laying around to
interfere with the build.

Of course, you probably don't want to modify the JSON build description file by
hand. For anything but trivial examples, it would be far too cumbersome and
error-prone to do so. The next three sections describe the solution to this
problem -- generating the build description.

### Implicit Dependencies

An implicit dependency (as opposed to an explicit dependency) is one that is not
specified in the build description, but discovered by running a task. The
canonical example of implicit dependencies are C/C++ header files. It is tedious
to explicitly specify these in the build description, but more importantly it is
error-prone.

Any task in the build graph, when executed, can tell Brilliant Build about its
input and output resources. This is a generalized way of allowing implicit
dependency detection. Tasks can be wrapped in another program that knows how to
tell Brilliant Build about detected dependencies. [`bbdeps`][bbdeps] is one such
wrapper program. It has fast ad hoc detection for various compilers but falls
back to tracing system calls for programs it doesn't know about. For example, in
order to do implicit dependency detection for the task:

    gcc -c foo.c -o foo.o

You would instead specify:

    bbdeps gcc -c foo.c -o foo.o

When executed, it tells Brilliant Build about any headers that were `#include`d
or transitively `#include`d.

#### Restrictions

There is one immutable rule that cannot be violated with implicit dependencies:
**an implicit dependency must not change the build order**. If this rule is
violated, the task will fail, Cthulhu will be summoned, and Brilliant Build will
tell you to explicitly add the would-be dependency to the build description. (If
you don't do it, Cthulhu will *find* you).

Allowing an implicit dependency to change the build order while the build is
running could lead to incorrect builds. More often, however, it is a mistake in
the build description. Therefore, this scenario is strictly forbidden.

[bbdeps]: https://github.com/jasonwhite/bbdeps

### Recursive Builds

Any task in the build graph can also be a build system. That is, Brilliant Build
can recursively run itself as part of the build. Doing this with `make` is
generally [considered harmful][RMCH] because it throws correct incremental
builds out the window. However, this is only because `make` doesn't know about
the dependencies of a sub-`make`. This is not a problem for Brilliant Build
because it knows how to send information about implicit dependencies to a parent
Brilliant Build process. By publishing implicit dependencies to the parent, the
child build system can be executed again if any of its inputs change.

[RMCH]: http://lcgapp.cern.ch/project/architecture/recursive_make.pdf

### Building the Build Description

Since we can correctly do recursive builds, we can also generate the build
description with, say, a scripting language as part of the build. The program
[`bblua`][bblua] is provided for this purpose. As the name might imply, it uses the
lightweight [Lua][] scripting language to specify build descriptions at a high
level. For example, this considerably more terse script (`BUILD.lua`) can
generate the JSON build description from the earlier section:

```lua
local cc = require "rules.cc"

cc.binary {
    name = "foobar",
    srcs = glob "*.c",
}
```

Unfortunately, we must still have an *upper* JSON build description as this is
what the parent Brilliant Build needs to read in:

```json
[
    {
        "inputs": ["BUILD.lua"],
        "task": ["bblua", "BUILD.lua", "-o", "build.bb.json"],
        "outputs": ["build.bb.json"]
    },
    {
        "inputs": ["build.bb.json"],
        "task": ["bb", "update", "--color=always", "-f", "build.bb.json"],
        "outputs": [".build.bb.json.state"]
    }
]
```

Fortunately, this rarely requires modification as most of the changes will be in
the Lua script as your project grows.

[bblua]: https://github.com/jasonwhite/bblua
[Lua]: https://www.lua.org/
