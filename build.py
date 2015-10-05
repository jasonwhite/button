#!/bin/env python3
# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Generates the rules necessary to build Brilliant Build.

import bb

def parse_args():
    """
    Parses arguments for the application.
    """
    import argparse

    parser = argparse.ArgumentParser(
            description='Generates the rules for building Brilliant Build.')
    parser.add_argument('output',
            type=argparse.FileType('w'),
            help='Path to the file to output the rules to')
    return parser.parse_args()

# TODO: Glob for *.d files.
rules = bb.dmd.binary('bb', [
    'source/bb/state/package.d',
    'source/bb/state/sqlite.d',
    'source/bb/vertex/package.d',
    'source/bb/vertex/task.d',
    'source/bb/vertex/resource.d',
    'source/bb/commands/help.d',
    'source/bb/commands/package.d',
    'source/bb/commands/status.d',
    'source/bb/commands/update.d',
    'source/bb/commands/graph.d',
    'source/bb/edgedata.d',
    'source/bb/edge.d',
    'source/bb/textcolor.d',
    'source/bb/graph.d',
    'source/bb/build.d',
    'source/bb/rule.d',
    'source/io/source/io/buffer/package.d',
    'source/io/source/io/buffer/traits.d',
    'source/io/source/io/buffer/fixed.d',
    'source/io/source/io/file/flags.d',
    'source/io/source/io/file/package.d',
    'source/io/source/io/file/mmap.d',
    'source/io/source/io/file/pipe.d',
    'source/io/source/io/file/temp.d',
    'source/io/source/io/file/stdio.d',
    'source/io/source/io/file/stream.d',
    'source/io/source/io/stream/package.d',
    'source/io/source/io/stream/primitives.d',
    'source/io/source/io/stream/types.d',
    'source/io/source/io/package.d',
    'source/io/source/io/range.d',
    'source/io/source/io/text.d',
    'source/change.d',
    'source/sqlite3.d',
    'source/app.d',
    ],
    compiler_flags=['-Isource', '-Isource/io/source', '-release', '-O', '-w'],
    linker_flags=['-L-lsqlite3']
    )

if __name__ == '__main__':
    args = parse_args()
    bb.dump(rules, f=args.output, indent=4)
