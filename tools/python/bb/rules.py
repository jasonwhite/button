# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Provides useful functions for generating rules for C/C++ projects.

from sys import stdout

class Rule:
    def __init__(self, inputs, task, outputs):
        self.inputs = inputs;
        self.task = task;
        self.outputs = outputs;

def dump(rules, f=stdout, **kwargs):
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
