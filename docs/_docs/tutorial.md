---
title: "Tutorial"
category: intro
order: 2
---

Table of contents:

* TOC
{:toc}

---

If you haven't done so already, follow the [installation instructions][] to
install Button.

[installation instructions]: {{ "/docs/install" | prepend: site.baseurl }}

## Setup

Suppose, in our `button-tutorial` directory, we have two C files and one header
file that we want to build:

    button-tutorial
    |-- bar.c
    |-- foo.c
    `-- foo.h

`foo.c`:

```c
#include "foo.h"

const char* foo()
{
    return "Hello world!";
}
```

`bar.c`:

```c
#include "foo.h"
#include <stdio.h>

int main()
{
    puts(foo());
    return 0;
}
```

`foo.h`:

```c
#ifndef FOO_H
#define FOO_H

const char* foo();

#endif // FOO_H
```

## Building Without a Build System

Without a build system, we might compile and link these like so:

    $ gcc -c foo.c -o foo.o
    $ gcc -c bar.c -o bar.o
    $ gcc foo.o bar.o -o foobar

Alternatively, it could have been done in one step:

    $ gcc foo.c bar.c -o foobar

However, that approach doesn't scale well with many source files. If only one
source file has changed since the last compilation, the compiler would be
duplicating a lot of work by building everything from scratch. Build systems
generally take the first approach so that only the necessary files are
recompiled.

## The Build Description

In order to automate the three steps above, we need to create a *build
description*. A build description lists every step necessary to build a project.

Button reads in the build description in JSON format. The above three steps
would look like this:

```json
[
    {
        "inputs": ["foo.c", "foo.h"],
        "task": [["gcc", "-c", "foo.c", "-o", "foo.o"]],
        "outputs": ["foo.o"]
    },
    {
        "inputs": ["bar.c", "foo.h"],
        "task": [["gcc", "-c", "bar.c", "-o", "bar.o"]],
        "outputs": ["bar.o"]
    },
    {
        "inputs": ["foo.o", "bar.o"],
        "task": [["gcc", "foo.o", "bar.o", "-o", "foobar"]],
        "outputs": ["foobar"]
    }
]
```

Obviously, you don't want to write this by hand for real-world projects.
However, for learning purposes, it is important to do it at least once. In later
sections, we will generate the build description as part of the build.

Name this JSON file `button.json`. Our source tree should then look like this:

    button-tutorial
    |-- bar.c
    |-- button.json
    |-- foo.c
    `-- foo.h

### Visualizing It

It can be very useful to see what the build description looks like. There is a
command to produce input for [GraphViz][]:

    $ button graph --full | dot -Tpng > build.png

![Build Graph]({{ site.baseurl }}/assets/img/build.png)

Like looking at a map, you can gain an immediate understanding of what the build
is doing by looking at its graph. See the documentation on [`button
graph`][button-graph] for more information.

[GraphViz]: http://www.graphviz.org/
[button-graph]: {{ "/docs/commands/graph" | prepend: site.baseurl }}

## Building It

To build it, simply run `button build`:

    $ button build
     > gcc -c foo.c -o foo.o
     > gcc -c bar.c -o bar.o
     > gcc foo.o bar.o -o foobar
    $ ./foobar
    Hello world!

By default, Button looks for a `button.json` file in the current directory (or
any parent directory). See the documentation on [`button build`][button-build]
for more information.

[button-build]: {{ "/docs/commands/build" | prepend: site.baseurl }}

Lets kick the tires and see what happens to the build under certain scenarios.

### The Null Build

Immediately running the build again, without changing anything, nothing will
happen:

    $ button build

Button sees that none of the source files have changed and so it has nothing to
do.

### Touching a File

What happens if we `touch` a file (i.e., change its modification time stamp)?

    $ touch foo.c
    $ button build

Nothing happened! Indeed, nothing *needs* to happen. The file itself didn't
change -- only the metadata associated with the file. While other build systems
use a file's time stamp to determine changes, Button determines changes based on
the checksum of a file's contents. This might seem like it would get slow for
many files, but the checksum is only recomputed if the time stamp changed.

### Modifying a File

Lets change the return string in `foo.c` to `"Farewell, cruel world!"` and run the
build again:

```c
#include "foo.h"

const char* foo()
{
    return "Farewell, cruel world!";
}
```

    $ button build
     > gcc -c foo.c -o foo.o
     > gcc foo.o bar.o -o foobar
    $ ./foobar
    Farewell, cruel world!

Of course, `foo.c` changed and so it got recompiled. Since `bar.c` hasn't
changed, there is no need to recompile it. It also relinked because `foo.o`
changed after recompiling `foo.c`.

### Deleting an Output

What happens if we delete the executable `foobar`?

    $ rm foobar
    $ button build
     - Warning: Output file `foobar` was changed externally and will be regenerated.
     > gcc foo.o bar.o -o foobar

Button sees that `foobar` doesn't exist anymore and rebuilds it. If `foobar` was
modified by us in some other way, it would have been rebuilt as well.

### Adding a Comment

Lets add a comment to `foo.c` and see what happens:

```c
#include "foo.h"

/**
 * Returns a pleasant greeting. Guaranteed to be random.
 */
const char* foo()
{
    return "Farewell, cruel world!";
}
```

    $ button build
     > gcc -c foo.c -o foo.o

Only `foo.c` was rebuilt. It wasn't relinked. Shouldn't it have relinked?

When compiling object files, `gcc` is deterministic. That is, given the same
input, it always produces the same output. Adding a comment to the source file
has no effect on the generated code and so `gcc` generates the same exact object
file as it would without the comment. Of course, this is specific to `gcc`. Not
all compilers are deterministic like this, but they should be (I'm looking at
*you* Microsoft!).

Here, the checksum of `foo.o` did not change from the previous build and so
Button avoids doing work that doesn't need to be done.

### Modifying the Build Description

How does Button handle changes to the build description?

Lets remove the compilation of `bar.c` from the build description and run the
build again. `button.json` should then look like this:

```json
[
    {
        "inputs": ["foo.c", "foo.h"],
        "task": [["gcc", "-c", "foo.c", "-o", "foo.o"]],
        "outputs": ["foo.o"]
    },
    {
        "inputs": ["foo.o", "bar.o"],
        "task": [["gcc", "foo.o", "bar.o", "-o", "foobar"]],
        "outputs": ["foobar"]
    }
]
```

    $ button build
     > gcc foo.o bar.o -o foobar
    gcc: error: bar.o: No such file or directory
       ➥ Task Error: Task failed
    :: Build failed! See the output above for details.

Linking failed because `bar.o` doesn't exist on disk! Button deleted `bar.o`.

Button stores the build description internally in a database and does a
comparison to what is in `button.json`. If it sees that a rule was removed, it
will delete its outputs from disk. This helps ensure that incremental builds,
even in the face of structural changes to the build description, are correct. If
`bar.o` hadn't been deleted, the link task would have happily succeeded. We
could have spent a long time tracking down why the program is misbehaving at
runtime. Instead it failed at build-time as it should.

## Going Meta: Building the Build Description

As mentioned earlier, writing the JSON build description by hand simply doesn't
scale for anything beyond trivial examples. Lets build the build description as
part of the build.

Go ahead and delete everything except the source files, including `button.json`.
We're going to start fresh:

    $ button clean --purge
    $ rm button.json

Our source should now look the same as it did at the start of the tutorial:

    button-tutorial
    |-- bar.c
    |-- foo.c
    `-- foo.h

Lets initialize it with some extra files:

    $ button init .

That created a few new files for us, so we don't have to do it manually. Our
source tree should now look like this:

    basic-example
    |-- bar.c
    |-- BUILD.lua
    |-- button.json
    |-- foo.c
    |-- foo.h
    `-- .gitignore

The important ones are `button.json` and `BUILD.lua`. Lets take a peek inside
`button.json`:

```json
[
    {
        "inputs": ["BUILD.lua"],
        "task": [["button-lua", "BUILD.lua", "-o", ".BUILD.lua.json"]],
        "outputs": [".BUILD.lua.json"]
    },
    {
        "inputs": [".BUILD.lua.json"],
        "task": [["button", "build", "--color=always", "-f", ".BUILD.lua.json"]],
        "outputs": [".BUILD.lua.json.state"]
    }
]
```

The first rule runs `button-lua` on the file `BUILD.lua` to generate the build
description `.BUILD.lua.json`. The second rule then runs Button with the
generated build description file.

Lets run a build:

    $ button build
     > button-lua BUILD.lua -o .BUILD.lua.json
     > button build --color=always -f .BUILD.lua.json

As expected, it ran the two rules in `button.json`, but the second rule didn't
really do anything. The generated `.BUILD.lua.json` has no rules in it because
`BUILD.lua` isn't creating them yet.

`BUILD.lua` currently only has a comment in it:

```lua
--[[
    This is the top-level build description. This is where you either create
    build rules or delegate to other Lua scripts to create build rules.

    See the documentation for more information on how to get started.
]]
```

To generate our rules using Lua, we can add this to the end of `BUILD.lua`:

{% raw %}
```lua
rule {
    inputs  = {"foo.c", "foo.h"},
    task    = {{"gcc", "-c", "foo.c", "-o", "foo.o"}},
    outputs = {"foo.o"},
}

rule {
    inputs  = {"bar.c", "foo.h"},
    task    = {{"gcc", "-c", "bar.c", "-o", "bar.o"}},
    outputs = {"bar.o"},
}

rule {
    inputs  = {"foo.o", "bar.o"},
    task    = {{"gcc", "foo.o", "bar.o", "-o", "foobar"}},
    outputs = {"foobar"},
}
```
{% endraw %}

`rule` is a function that takes a table as an argument. Since we're working with
a full-fledged programming language, we can add more abstractions so it isn't so
verbose. Indeed, there are modules to do exactly that:

```lua
local cc = require "rules.cc"

cc.binary {
    name = "foobar",
    srcs = glob "*.c",
}
```

`"rules.cc"` is a module that lets you generate rules for C and C++ builds.
Here, calling `cc.binary` generates the compilation and linker rules for us.
This is the JSON file it generates:

```json
[
    {
        "inputs": ["bar.c"],
        "task": [["button-deps", "--", "gcc", "-c", "bar.c", "-o", "bar.c.o"]],
        "outputs": ["bar.c.o"],
        "display": "cc bar.c"
    },
    {
        "inputs": ["foo.c"],
        "task": [["button-deps", "--", "gcc", "-c", "foo.c", "-o", "foo.c.o"]],
        "outputs": ["foo.c.o"],
        "display": "cc foo.c"
    },
    {
        "inputs": ["bar.c.o", "foo.c.o"],
        "task": [["button-deps", "--", "gcc", "-o", "./foobar", "bar.c.o", "foo.c.o"]],
        "outputs": ["./foobar"],
        "display": "ld foobar"
    }
]
```

Notice that each task is prefixed with `["button-deps", "--",`. The program
`button-deps` wraps the `gcc` command in order to provide automatic dependency
detection. Any header files that are brought in with `#include` will get
detected. That way, after the initial compilation, when a header file is
changed, Button knows which tasks it needs to rerun in order to keep the build
in a consistent state. Likewise, `button-deps` discovers outputs automatically
so that Button can correctly delete them later if/when they are no longer
outputs.

You may also notice that there is a new `"display"` field. This just gives a
human-readable name to the task. The display name is printed in the output
instead of the command line of the task. It is not uncommon for command lines to
get very long and thus very unreadable. Linker commands that are linking in many
object files are usually the biggest offenders.

Your `BUILD.lua` should now look like this:

```lua
--[[
    This is the top-level build description. This is where you either create
    build rules or delegate to other Lua scripts to create build rules.

    See the documentation for more information on how to get started.
]]

local cc = require "rules.cc"

cc.binary {
    name = "foobar",
    srcs = glob "*.c",
}
```

Now we can run a build:

    $ button build
     > button build --color=always -f .BUILD.lua.json
     > cc bar.c
     > cc foo.c
     > ld foobar

Notice that the display names were shown instead of the full command lines.

`BUILD.lua` can be freely modified and Button will detect changes to it and
rebuild as necessary. If we modify `BUILD.lua` without changing how the build
description is generated, nothing will get rebuilt.
