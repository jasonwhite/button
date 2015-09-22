/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Helper module for colorizing terminal output.
 */
module bb.textcolor;

// TODO: Make all of these empty strings if the terminal doesn't support it or
// if we don't want colorized output.

/*
 * Black        0;30     Dark Gray     1;30
 * Red          0;31     Light Red     1;31
 * Green        0;32     Light Green   1;32
 * Brown/Orange 0;33     Yellow        1;33
 * Blue         0;34     Light Blue    1;34
 * Purple       0;35     Light Purple  1;35
 * Cyan         0;36     Light Cyan    1;36
 * Light Gray   0;37     White         1;37
*/

immutable black     = "\033[0;30m", boldBlack     = "\033[1;30m",
          red       = "\033[0;31m", boldRed       = "\033[1;31m",
          green     = "\033[0;32m", boldGreen     = "\033[1;32m",
          orange    = "\033[0;33m", boldOrange    = "\033[1;33m",
          blue      = "\033[0;34m", boldBlue      = "\033[1;34m",
          purple    = "\033[0;35m", boldPurple    = "\033[1;35m",
          cyan      = "\033[0;36m", boldCyan      = "\033[1;36m",
          lightGray = "\033[0;37m", boldLightGray = "\033[1;37m";

immutable bold       = "\033[1m";
immutable resetColor = "\033[0m";

immutable successColor = green;
immutable errorColor   = boldRed;
immutable warningColor = boldOrange;
immutable statusColor  = blue;
