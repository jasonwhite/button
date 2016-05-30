[buildbadge]: https://travis-ci.org/jasonwhite/button.svg?branch=master
[buildstatus]: https://travis-ci.org/jasonwhite/button

# Button [![Build Status][buildbadge]][buildstatus]

A build system that aims to be fast, correct, and elegantly simple. See the
[documentation][] for more information.

[documentation]: http://jasonwhite.github.io/button/

## Features

 * Implicit dependency detection.
 * Correct incremental builds.
 * Can display a graph of the build.
 * Recursive. Can generate a build description as part of the build.
 * Very general. Does not make any assumptions about the structure of your
   project.
 * Detects and displays cyclic dependencies.
 * Detects race conditions.

## "Ugh! Another build system! [Why?!][relevant xkcd]"

[relevant xkcd]: https://xkcd.com/927/

There are many, *many* other build systems out there. There are also many,
*many* programming languages out there, but that hasn't stopped anyone from
making even more. Advancing the state of a technology is all about incremental
improvement. Button's raison d'être is to advance the state of build systems.
Building software is a wildly complex task and we need a build system that can
cope with that complexity without being too restrictive.

Most build systems tend to suffer from one or more of the following problems:

 1. They don't do correct incremental builds.
 2. They don't correctly track changes to the build description.
 3. They don't scale well with large projects (100,000+ source files).
 4. They are language-specific or aren't general enough to be widely used
    outside of a niche community.
 5. They are tied to a domain specific language.

Button is designed such that it can solve all of these problems. Read the
[overview][] in the documentation to find out how.

[overview]: http://jasonwhite.github.io/button/docs/

## License

[MIT License](/LICENSE)
