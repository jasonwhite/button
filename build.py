#!/bin/env python3
# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Generates the rules necessary to build Brilliant Build.

import bb
from glob import glob
from itertools import chain

def parse_args():
    """Parses arguments for the application."""
    import argparse

    parser = argparse.ArgumentParser(
            description='Generates the rules for building Brilliant Build.')
    parser.add_argument('output',
            type=argparse.FileType('w'),
            help='Path to the file to output the rules to')
    return parser.parse_args()


dmd_flags=['-Isource/io/source', '-release', '-w']
prefix=['./bb-wrap-bootstrap']

io_rules = bb.dmd.static_library(
        path = 'io',
        sources = glob('source/io/source/io/**/*.d', recursive=True),
        compiler_flags = dmd_flags,
        prefix = prefix,
        )

bb_rules = bb.dmd.binary(
        path = 'bb',
        sources = glob('source/util/*.d') + \
                  glob('source/bb/**/*.d', recursive=True),
        libraries = ['io'],
        compiler_flags = ['-Isource'] + dmd_flags,
        linker_flags = ['-L-lsqlite3'],
        prefix = prefix,
        )

wrap_rules = bb.dmd.binary(
        path = 'bb-wrap',
        sources = glob('source/wrap/source/wrap/**/*.d', recursive=True),
        libraries = ['io'],
        compiler_flags = ['-Isource/wrap/source'] + dmd_flags,
        prefix = prefix,
        )

rules = chain(io_rules, bb_rules, wrap_rules)

if __name__ == '__main__':
    args = parse_args()
    bb.dump(rules, f=args.output, indent=4)
