/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Removes comments and unnecessary whitespace from a Lua file. This is useful
 * for embedding Lua scripts into an executable.
 */
#include <stdio.h>
#include <string.h>
#include <ctype.h>

const char* read_file(FILE* f, size_t* len) {

    // Find the length of the file
    fseek(f, 0, SEEK_END);
    *len = (size_t)ftell(f);
    if (fseek(f, 0, SEEK_SET) != 0) {
        return NULL;
    }

    char* buf = new char[*len];

    if (!buf || fread(buf, 1, *len, f) != *len) {
        return NULL;
    }

    return (const char*)buf;
}

size_t skip_block_comment(const char* buf, size_t len) {
    size_t i = 0;

    if (len >= 4 && strncmp(buf, "--[[", 4) == 0) {
        i += 4;

        while (i < (len - 2)) {
            if (strncmp(buf+i, "]]", 2) == 0) {
                i += 2;
                return i;
            }

            ++i;
        }
    }

    return i;
}

enum StringType {
    STRING_NONE,
    STRING_BLOCK,
    STRING_SINGLE,
    STRING_DOUBLE,
};

size_t skip_string(const char* buf, size_t len) {
    size_t i = 0;

    StringType t = STRING_NONE;

    if (i < len) {
        switch (buf[i]) {
            case '"': t = STRING_DOUBLE; i += 1; break;
            case '\'': t = STRING_SINGLE; i += 1; break;
            case '[':
                if ((len-i) >= 2 && buf[i+1] == '[') {
                    t = STRING_BLOCK;
                    i += 2;
                    break;
                }
                return 0;
            default:
                return 0;
        }
    }

    while (i < len) {
        switch (buf[i]) {
            case '"':
                if (t == STRING_DOUBLE && buf[i-1] != '\\')
                    return i+1;
                break;
            case '\'':
                if (t == STRING_SINGLE && buf[i-1] != '\\')
                    return i+1;
                break;
            case ']':
                if (t == STRING_BLOCK && buf[i-1] != '\\' &&
                    (len-i) > 0 && buf[i+1] == ']')
                    return i+2;
                break;
        }

        ++i;
    }

    if (i > 0)
        fwrite(buf, 1, i, stdout);

    return i;
}

size_t skip_line_comment(const char* buf, size_t len) {
    size_t i = 0;

    if (len >= 2 && strncmp(buf, "--", 2) == 0) {
        i += 2;

        while (i < len && buf[i] != '\n')
            ++i;

        if (buf[i-1] == '\n')
            --i;
    }

    return i;
}

size_t skip_trailing_spaces(const char* buf, size_t len) {
    size_t i = 0;

    // Replace \s*\n with \n
    while (i < len && isblank(buf[i]))
        ++i;

    if (i < len && buf[i] == '\n')
        return i;

    return 0;
}

size_t skip_whitespace(const char* buf, size_t len) {
    size_t i = 0;

    // Replace \n\s* with \n
    if (len > 0 && buf[i] == '\n') {
        ++i;

        while (i < len && isspace(buf[i]))
            ++i;

        putchar('\n');
    }

    return i;
}

void minify(const char* buf, size_t len) {

    size_t delta = 0;

    for (size_t i = 0; i < len; ) {
        while (true) {
            delta = 0;
            delta += skip_block_comment(buf+i+delta, len-i-delta);
            delta += skip_line_comment(buf+i+delta, len-i-delta);
            delta += skip_trailing_spaces(buf+i+delta, len-i-delta);
            delta += skip_whitespace(buf+i+delta, len-i-delta);
            delta += skip_string(buf+i+delta, len-i-delta);

            // As long as we can keep doing work, keep going.
            if (delta > 0) {
                i += delta;
                continue;
            }

            break;
        }

        putchar(buf[i]);
        ++i;
    }
}

int main(int argc, char** argv)
{
    if (argc <= 1) {
        puts("Usage: luamin FILE");
        return 1;
    }

    FILE* f = fopen(argv[1], "rb");
    if (!f) {
        perror("failed to open file");
        return 1;
    }

    size_t len;
    const char* buf = read_file(f, &len);

    fclose(f);

    if (!buf) {
        perror("failed to read file");
        return 1;
    }

    minify(buf, len);

    return 0;
}
