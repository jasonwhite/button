# Brilliant Build

A build system that aims to be *scalable* and *correct*.

*This is a work in progress.*

## Quick Example

### Build Description

Here is a simple example of a build description:

```json
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
```

Note that build descriptions are not intended to be written by hand. For
projects more complicated than this, one should generate the build description.
Note that Brilliant Build can be used as a task in a "root" build description to
help achieve this.

### Visualizing the Build

A visualization of the above build description can be generated using
[GraphViz][]:

```bash
$ bb graph | dot -Tpng > basic.png
```
![Simple Task Graph](/docs/examples/basic/build.png)

[GraphViz]: http://www.graphviz.org/

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
$ touch foo.c
$ bb update
 > gcc -c foo.c -o foo.o
 > gcc foo.o bar.o -o foobar
```

## License

[MIT License](/LICENSE.md)
