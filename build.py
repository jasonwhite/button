#!/bin/env python3
# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Generates the rules necessary to build Brilliant Build.

import bb
import glob

def parse_args():
    """Parses arguments for the application."""
    import argparse

    parser = argparse.ArgumentParser(
            description='Generates the rules for building Brilliant Build.')
    parser.add_argument('output',
            type=argparse.FileType('w'),
            help='Path to the file to output the rules to')
    return parser.parse_args()

# TODO: Use the new recursive glob
sources = glob.glob('source/*.d') + \
          glob.glob('source/bb/*.d') + \
          glob.glob('source/bb/commands/*.d') + \
          glob.glob('source/bb/state/*.d') + \
          glob.glob('source/bb/vertex/*.d') + \
          glob.glob('source/io/source/io/*.d') + \
          glob.glob('source/io/source/io/buffer/*.d') + \
          glob.glob('source/io/source/io/file/*.d') + \
          glob.glob('source/io/source/io/stream/*.d')

# TODO: Break io module off into separate static library
rules = bb.dmd.binary('bb', sources,
        compiler_flags=['-Isource', '-Isource/io/source', '-release', '-O', '-w'],
        linker_flags=['-L-lsqlite3']
        )

if __name__ == '__main__':
    args = parse_args()
    bb.dump(rules, f=args.output, indent=4)
