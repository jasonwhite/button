---
title: "Installation"
category: intro
order: 1
---

Unfortunately, there are no operating system packages for Button yet. It must be
built from source.

**NOTE**: Button is currently only supported on Linux. If you're on OS X or
Windows, you are out of luck. The good news is that there isn't much work to do
to support these operating systems. Any help with this would be greatly
appreciated.

## Building It

Button consists of three main components:

 1. The core build system itself (`button`). This is what runs the actual build.
 2. The implicit dependency detector (`button-deps`).
 3. The build description generator from Lua scripts (`button-lua`).

Optionally, there is also the Makefile-to-Button build description converter
(`button-make`). This is only needed if you want to automatically convert
Makefiles to Button's build description format.

### Prerequisites

To build, you'll need:

 1. [Git](https://git-scm.com/).
 2. [Make](https://www.gnu.org/software/make/).
 2. [DMD](http://dlang.org/download.html), the D compiler.
 3. [DUB](http://code.dlang.org/download), The D package manager.

If you're running a relatively recent Linux distribution, there are probably
packages available for these already.

### Building `button`

 1. Get the source:

    ```bash
    $ git clone https://github.com/jasonwhite/button.git && cd button
    ```

 2. Build it:

    ```bash
    $ dub build --build=release
    ```

There should now be a `button` executable in the current directory. Put this in
a directory that is in your `$PATH` and run it to make sure it is working:

    $ button help

### Building `button-deps`

 1. Get the source:

    ```bash
    $ git clone https://github.com/jasonwhite/button-deps.git && cd button-deps
    ```

 2. Build it:

    ```bash
    $ dub build --build=release
    ```

There should now be a `button-deps` executable in the current directory. Put
this in a directory that is in your `$PATH` and run it to make sure it is
working:

    $ button-deps
    Usage: button-deps [--json FILE] -- program [arg...]

### Building `button-lua`

`button-lua` is written in C++ and thus the build process is a little different.

 1. Get the source:

    ```bash
    $ git clone --recursive https://github.com/jasonwhite/button-lua.git && cd button-lua
    ```

 2. Build it:

    ```
    $ make
    ```

There should now be a `button-lua` executable in the current directory. Copy it
to a directory that is in your `$PATH` and run it to make sure it is working:

    $ button-lua
    Usage: button-lua <script> [-o output] [args...]

### Building `button-make`

This is entirely optional. This is only needed if you have Makefiles you want to
build and/or visualize.

`button-make` is a modified version of GNU Make and thus the build process is
the same as building `make`:

 1. Get the source:

    ```bash
    $ git clone https://github.com/jasonwhite/button-make.git && cd button-make
    ```

 2. Build it:

    ```bash
    $ autoreconf -i
    $ ./configure --prefix=$(pwd)/install --program-prefix=button-
    $ make update
    $ make && make install
    ```

There should now be an `install` directory in the current directory. Copy
`install/bin/button-make` to a directory that is in your `$PATH` and run it to
make sure it is working:

    $ button-make --version

If you run into problems, see GNU Make's own [README.git][] for more information
on building from source. If that fails you, please [submit an
issue](https://github.com/jasonwhite/button-make/issues).

[README.git]: https://github.com/jasonwhite/button-make/blob/master/README.git
