---
title: "button graph"
category: commands
---

Produces output to be consumed by [GraphViz][]. This is useful for visualising
the build graph.

[GraphViz]: http://www.graphviz.org/

## Example

To generate a PNG image of your build graph, run:

    $ button graph | dot -Tpng > build_graph.png

Note that `dot` is part of [GraphViz][].

If running X11, you can also display an interactive graph:

    $ button graph | dot -Tx11

## Optional Arguments

 * `--file`, `-f <string>`

    Specifies the path to the build description.

 * `--changes`, `-C`

    Only display the subgraph that will be traversed in the next build.

 * `--cached`

    Displays the cached graph from the previous build. By default, changes to
    the build description are represented in the graph.

 * `--full`

    Displays the full name of each vertex. By default, the names of vertices are
    shown in condensed form. That is, resource paths are shortened to their
    basename and the display name of tasks (if available) are shown. If this
    option is specified, resource paths are shown in full and the full command
    line for a task is shown. This is off by default because it often makes
    vertices in the graph quite large.

 * `--edges`, `-e {explicit,implicit,both}`

    Type of edges to show.

 * `--threads`, `-j N`

    The number of threads to use. By default, the number of logical cores is
    used.

