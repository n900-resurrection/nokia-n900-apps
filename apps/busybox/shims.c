/* Functions that BusyBox 1.37 calls but the glibc 2.5 of Maemo 5 does not have.
 * utimensat() is a system call since kernel 2.6.22 (ARM: 348), so it exists on the 2.6.28 kernel. */
#define _GNU_SOURCE
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

int utimensat(int dirfd, const char *path, const struct timespec ts[2], int flags)
{
    return syscall(348 /* __NR_utimensat on ARM */, dirfd, path, ts, flags);
}

int futimens(int fd, const struct timespec ts[2])
{
    return utimensat(fd, NULL, ts, 0);
}
