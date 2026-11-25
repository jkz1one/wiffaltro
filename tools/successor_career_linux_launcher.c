#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

#define DATA_LEAF "WiffaltroCareerQualification-v1"
#define LOCK_FD 198

/* Walk the fixed data path without traversing symlinks. Lock the career
 * directory itself, not a temporary file or a file in the install folder. */
static int open_data_leaf(const char *path) {
    if (!path || path[0] != '/') return -1;
    char *copy = strdup(path);
    if (!copy) return -1;
    int fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    char *state = NULL;
    for (char *part = strtok_r(copy, "/", &state); fd >= 0 && part;
         part = strtok_r(NULL, "/", &state)) {
        if (!strcmp(part, ".") || !strcmp(part, "..")) {
            close(fd);
            fd = -1;
            break;
        }
        if (mkdirat(fd, part, 0700) && errno != EEXIST) {
            close(fd);
            fd = -1;
            break;
        }
        int child = openat(fd, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        close(fd);
        fd = child;
    }
    free(copy);
    return fd;
}

int main(int argc, char **argv) {
    (void)argv;
    if (argc != 1) {
        fputs("Wiffaltro Career Qualification does not accept launch arguments.\n", stderr);
        return 3;
    }
    char game[PATH_MAX];
    ssize_t size = readlink("/proc/self/exe", game, sizeof(game) - 1);
    if (size <= 0 || (size_t)size >= sizeof(game) - 1) return 4;
    game[size] = '\0';
    char *base = strrchr(game, '/');
    if (!base || (size_t)(base - game) + sizeof "/Wiffaltro.x86_64" > sizeof(game)) return 4;
    strcpy(base + 1, "Wiffaltro.x86_64");

    char path[PATH_MAX];
    const char *data = getenv("XDG_DATA_HOME");
    const char *home = getenv("HOME");
    int n = data && *data ? snprintf(path, sizeof(path), "%s/" DATA_LEAF, data)
                         : home && *home ? snprintf(path, sizeof(path), "%s/.local/share/" DATA_LEAF, home) : -1;
    if (n < 0 || (size_t)n >= sizeof(path)) return 4;
    int fd = open_data_leaf(path);
    struct stat st;
    if (fd < 0 || fstat(fd, &st) || st.st_uid != geteuid() || (st.st_mode & 0022)) {
        fputs("Wiffaltro could not open a private career folder. No save was opened.\n", stderr);
        return 4;
    }
    if (flock(fd, LOCK_EX | LOCK_NB)) {
        if (errno == EWOULDBLOCK) {
            fputs("Wiffaltro is already open for this career. No save was opened.\n", stderr);
            return 5;
        }
        fputs("Wiffaltro could not lock the career folder. No save was opened.\n", stderr);
        return 4;
    }
    if (fd == LOCK_FD ? fcntl(fd, F_SETFD, 0) < 0 : dup2(fd, LOCK_FD) < 0) return 4;
    if (fd != LOCK_FD) close(fd);

    /* exec keeps both the flock and its PID through the actual game lifetime. */
    char *const launch[] = {game, NULL};
    execv(game, launch);
    perror("Wiffaltro could not start");
    return 4;
}
