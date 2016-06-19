/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Command handler package. A command handler takes in a command line, executes
 * it, and returns a set of implicit inputs/outputs. Handlers can be called by
 * other handlers.
 *
 * This is useful for ad-hoc dependency detection. For example, to detect
 * inputs/outputs when running DMD, we modify the command line so it writes them
 * to a file which we then read in to determine the inputs/outputs.
 *
 * If there is no handler, we default to system call tracing.
 */
module button.core.handlers;

// List of all handler types
public import button.core.handlers.base      : base      = execute;
public import button.core.handlers.recursive : recursive = execute;
public import button.core.handlers.dmd       : dmd       = execute;
public import button.core.handlers.gcc       : gcc       = execute;
public import button.core.handlers.tracer    : tracer    = execute;
