===============
Brilliant Build
===============

A build system that aims to be *scalable* and *correct*.

*This is a work in progress.*

---------------
A Quick Example
---------------

The Build Description
=====================

Here is a simple example of a build description:

.. code:: json

    {
        "rules": [
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
                "outputs": ["foobar"],
                "display": "Linking foobar"
            }
        ]
    }

.. note::

    Build descriptions are not intended to be written by hand. For projects more
    complicated than this, one should generate the build description.  Note that
    Brilliant Build can be used as a task in a "root" build description to help
    achieve this.

Visualizing the Build
=====================

A visualization of the above build description can be generated using GraphViz_:

.. code:: bash

    $ brilliant-build show basic.json | dot -Tpng > basic.png

.. image:: /docs/examples/basic/build.png
    :alt: A simple task graph.

.. _GraphViz: http://www.graphviz.org/

Running the Build
=================

Suppose this is our first time running the build. In that case, we will see a
full build:

.. code:: bash

    $ brilliant-build update basic.json
     > gcc -c bar.c -o bar.o
     > gcc -c foo.c -o foo.o
     > gcc foo.o bar.o -o foobar

If we run it again immediately without changing any files, nothing will happen:

.. code:: bash

    $ brilliant-build update basic.json

Now suppose we make a change to the file ``foo.c`` and run the build again. Only
the necessary tasks to bring the outputs up-to-date are executed:

.. code:: bash

    $ touch foo.c
    $ brilliant-build update basic.json
     > gcc -c foo.c -o foo.o
     > gcc foo.o bar.o -o foobar

-------
License
-------

`MIT License </LICENSE.md>`_
