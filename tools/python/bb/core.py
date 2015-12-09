# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Provides useful functions for generating rules for C/C++ projects.

from sys import stdout

class Rule:
    """A rule is the fundamental unit in the build system. All targets
    eventually boil down to one or more rules.
    """

    def __init__(self, inputs, task, outputs):
        self.inputs = inputs;
        self.task = task;
        self.outputs = outputs;

class Target:
    """Base target class.
    """

    # Command to prepend to all others
    wrapper = []

    def __init__(self, name, deps=[], srcs=[]):
        self.name = name;
        self.deps = deps;
        self.srcs = srcs;

class TargetError(Exception):
    """Dummy exception for easier error reporting.
    """
    pass

def rules(targets):
    """Generates the rules for the given list or iterable of targets.
    """

    index = {}

    targets = list(targets)

    for target in targets:
        if target.name in index:
            raise TargetError('Target name "%s" is not unique' % target.name)

        index[target.name] = target

    for target in targets:
        deps = None
        try:
            deps = [index[name] for name in target.deps]
        except KeyError as e:
            raise TargetError("Dependency %s does not exist for target '%s'" %
                    (e, target.name))

        yield from target.rules(deps)

def dump_rules(rules, f=stdout, **kwargs):
    """Dumps the list of rules to the given file."""
    import json

    json.dump(
        [
            {
                'inputs': r.inputs,
                'task': r.task,
                'outputs': r.outputs
            } for r in rules
        ], f, sort_keys=True, **kwargs
        )

def dump(targets, f=stdout, **kwargs):
    """Helper function for both translating targets to rules and dumping them.
    """
    dump_rules(rules(targets), f=f, **kwargs)

def main(targets):
    """Helper main function.
    """
    import argparse
    from sys import stderr

    parser = argparse.ArgumentParser(
            description='Generates the build description.')
    parser.add_argument('output',
            type=argparse.FileType('w'),
            help='Path to the file to output the build description to')
    args = parser.parse_args()

    try:
        dump(targets, f=args.output, indent=4)
    except TargetError as e:
        print('Error:', e, file=stderr)


from glob import glob as orig_glob
from itertools import chain

def glob(patterns):
    """Convenience function for globbing with multiple patterns at once.
    """
    return set(chain(*[orig_glob(p, recursive=True) for p in patterns]))
