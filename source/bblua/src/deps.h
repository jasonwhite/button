/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Handles sending dependencies to parent build system.
 */
#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>

#ifdef _WIN32
#   error "Implement me!"
#endif

struct Dependency {

    /**
     * Set to 0 if this dependency is an input to this task, 1 if an output.
     */
    uint16_t output : 1;

    /**
     * Currently unused. May be used when additional resource types are added
     * (such as environment variables). For now, always set this to 0.
     */
    uint16_t type : 15;

    /**
     * Length of the name.
     */
    uint16_t length;

    /**
     * Timestamp of the resource. If unknown, this should be set to 0. In such a
     * case, the parent build system will compute the value when needed. This is
     * used by the parent build system to determine if the checksum needs to be
     * recomputed.
     *
     * For files and directories, this is its last modification time.
     */
    uint64_t timestamp;

    /**
     * SHA-256 checksum of the contents of the resource. If unknown or not
     * computed, this should be set to 0. In such a case, the parent build
     * system will compute the value when needed.
     *
     * For files, this is the checksum of the file contents. For directories,
     * this is the checksum of the paths in the sorted directory listing.
     */
    uint8_t checksum[32];

    /**
     * Name of the resource that can be used to lookup the data. Length is given
     * by the length member.
     *
     * This is usually a file or directory path. The path do not need to be
     * normalized. If a relative path, the build system assumes it is relative
     * to the working directory that the child was spawned in.
     */
    char name[0];
};

/**
 * Handles sending dependencies to the parent build system (if any).
 *
 * When creating child processes, the parent build system will set the
 * environment variable BB_DEPS to the file descriptor that can be used to send
 * back dependency information from the child process. This is the generic
 * interface for making implicit inputs and outputs known to the parent build
 * system.
 */
class ImplicitDeps {
private:
    FILE* _f;

public:
    ImplicitDeps();
    ~ImplicitDeps();

    /**
     * Returns true if there is a parent build system to send dependencies to.
     */
    bool hasParent() const;

    /**
     * Adds the given dependency.
     */
    void add(const Dependency& dep);

    /**
     * Adds a dependency by name only.
     */
    void addInputFile(const char* name, size_t length);
    void addOutputFile(const char* name, size_t length);
};
