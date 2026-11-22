/* Link-time shims that let the Ubuntu libstdc++.a / libgcc (built for glibc 2.39) run on glibc 2.5 (Maemo 5).
 * scripts/maemo-g++ links this file in. Each function here is a symbol the new libstdc++ asks for that glibc 2.5 lacks. */
#define _GNU_SOURCE
#define _LARGEFILE64_SOURCE
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <math.h>
#include <time.h>
#include <pthread.h>

char __libc_single_threaded = 0;                      /* always "threaded": libstdc++ then uses atomic operations */

char *secure_getenv(const char *name) { return getenv(name); }
unsigned long __isoc23_strtoul(const char *s, char **e, int b) { return strtoul(s, e, b); }
long __isoc23_strtol(const char *s, char **e, int b) { return strtol(s, e, b); }
unsigned long long __isoc23_strtoull(const char *s, char **e, int b) { return strtoull(s, e, b); }
long long __isoc23_strtoll(const char *s, char **e, int b) { return strtoll(s, e, b); }

int getentropy(void *buf, size_t n)
{
    int fd = open("/dev/urandom", O_RDONLY);
    size_t got = 0;
    if (fd < 0) return -1;
    while (got < n) {
        ssize_t r = read(fd, (char *)buf + got, n - got);
        if (r <= 0) { close(fd); return -1; }
        got += (size_t)r;
    }
    close(fd);
    return 0;
}
unsigned int arc4random(void) { unsigned int v; getentropy(&v, sizeof v); return v; }

int __ioctl_time64(int fd, unsigned long req, void *arg) { return ioctl(fd, req, arg); }

void *aligned_alloc(size_t align, size_t size)
{
    void *p;
    if (align < sizeof(void *)) align = sizeof(void *);
    return posix_memalign(&p, align, size) ? NULL : p;
}
int at_quick_exit(void (*f)(void)) { return atexit(f); }
void quick_exit(int code) { _exit(code); }

/* long double == double on ARM, and glibc 2.5 declares no *l functions for it (libstdc++ expects them) */
long double acoshl(long double x) { return acosh(x); }
long double asinhl(long double x) { return asinh(x); }
long double atanhl(long double x) { return atanh(x); }
long double cbrtl(long double x) { return cbrt(x); }
long double erfl(long double x) { return erf(x); }
long double erfcl(long double x) { return erfc(x); }
long double exp2l(long double x) { return exp2(x); }
long double expm1l(long double x) { return expm1(x); }
long double lgammal(long double x) { return lgamma(x); }
long double log1pl(long double x) { return log1p(x); }
long double log2l(long double x) { return log2(x); }
long double logbl(long double x) { return logb(x); }
long double nearbyintl(long double x) { return nearbyint(x); }
long double rintl(long double x) { return rint(x); }
long double roundl(long double x) { return round(x); }
long double truncl(long double x) { return trunc(x); }
long double tgammal(long double x) { return tgamma(x); }
long double copysignl(long double x, long double y) { return copysign(x, y); }
long double fdiml(long double x, long double y) { return fdim(x, y); }
long double fmaxl(long double x, long double y) { return fmax(x, y); }
long double fminl(long double x, long double y) { return fmin(x, y); }
long double hypotl(long double x, long double y) { return hypot(x, y); }
long double nextafterl(long double x, long double y) { return nextafter(x, y); }
long double nexttowardl(long double x, long double y) { return nexttoward(x, y); }
long double remainderl(long double x, long double y) { return remainder(x, y); }
long double fmal(long double x, long double y, long double z) { return fma(x, y, z); }
int ilogbl(long double x) { return ilogb(x); }
long long llrintl(long double x) { return llrint(x); }
long long llroundl(long double x) { return llround(x); }
long lrintl(long double x) { return lrint(x); }
long lroundl(long double x) { return lround(x); }
long double nanl(const char *s) { return nan(s); }
long double remquol(long double x, long double y, int *q) { return remquo(x, y, q); }
long double scalblnl(long double x, long n) { return scalbln(x, n); }
long double scalbnl(long double x, int n) { return scalbn(x, n); }
int timespec_get(struct timespec *ts, int base) { return base == 1 && clock_gettime(CLOCK_REALTIME, ts) == 0 ? base : 0; }

/* glibc 2.30+ functions with a clock argument (libstdc++ uses them for steady_clock waits). Waits against CLOCK_MONOTONIC are converted to a
 * CLOCK_REALTIME deadline (a clock jump during the wait only shortens or lengthens it). */
static void to_realtime(clockid_t clk, const struct timespec *abs, struct timespec *out)
{
    if (clk == CLOCK_REALTIME) { *out = *abs; return; }
    struct timespec now_c, now_r;
    clock_gettime(clk, &now_c); clock_gettime(CLOCK_REALTIME, &now_r);
    out->tv_sec = now_r.tv_sec + (abs->tv_sec - now_c.tv_sec);
    out->tv_nsec = now_r.tv_nsec + (abs->tv_nsec - now_c.tv_nsec);
    if (out->tv_nsec >= 1000000000L) { out->tv_sec++; out->tv_nsec -= 1000000000L; }
    if (out->tv_nsec < 0) { out->tv_sec--; out->tv_nsec += 1000000000L; }
}
int pthread_cond_clockwait(pthread_cond_t *c, pthread_mutex_t *m, clockid_t clk, const struct timespec *abs)
{ struct timespec r; to_realtime(clk, abs, &r); return pthread_cond_timedwait(c, m, &r); }
int pthread_mutex_clocklock(pthread_mutex_t *m, clockid_t clk, const struct timespec *abs)
{ struct timespec r; to_realtime(clk, abs, &r); return pthread_mutex_timedlock(m, &r); }

/* ---- 64-bit time_t ABI ----------------------------------------------------------------------------------------------------------------
 * The Ubuntu libstdc++.a was built with a 64-bit time_t: it calls __clock_gettime64 & co. with 16-byte timespecs and a 112-byte struct stat.
 * glibc 2.5 (and the kernel 2.6.28 of the phone) know only the 32-bit forms, so the calls are translated here. The layouts below were
 * measured with the Ubuntu headers (-D_TIME_BITS=64: sizeof stat 112, timespec 16, st_size at 40, st_atim at 64). */
#include <sys/syscall.h>
#include <sys/time.h>
struct ts64 { long long sec; int nsec; int pad; };
struct tv64 { long long sec; long long usec; };
struct stat_t64 {
    unsigned long long st_dev, st_ino;
    unsigned int st_mode, st_nlink, st_uid, st_gid;
    unsigned long long st_rdev;
    long long st_size;
    int st_blksize, pad0;
    long long st_blocks;
    struct ts64 st_atim, st_mtim, st_ctim;
};
_Static_assert(sizeof(struct stat_t64) == 112, "struct stat of the 64-bit time ABI");

static void fill_stat(struct stat_t64 *o, const struct stat64 *s)
{
    memset(o, 0, sizeof *o);
    o->st_dev = s->st_dev; o->st_ino = s->st_ino; o->st_mode = s->st_mode; o->st_nlink = s->st_nlink;
    o->st_uid = s->st_uid; o->st_gid = s->st_gid; o->st_rdev = s->st_rdev; o->st_size = s->st_size;
    o->st_blksize = (int)s->st_blksize; o->st_blocks = s->st_blocks;
    o->st_atim.sec = s->st_atime; o->st_atim.nsec = (int)s->st_atim.tv_nsec;
    o->st_mtim.sec = s->st_mtime; o->st_mtim.nsec = (int)s->st_mtim.tv_nsec;
    o->st_ctim.sec = s->st_ctime; o->st_ctim.nsec = (int)s->st_ctim.tv_nsec;
}
int __fstat64_time64(int fd, struct stat_t64 *o) { struct stat64 s; int r = fstat64(fd, &s); if (!r) fill_stat(o, &s); return r; }
int __stat64_time64(const char *p, struct stat_t64 *o) { struct stat64 s; int r = stat64(p, &s); if (!r) fill_stat(o, &s); return r; }
int __lstat64_time64(const char *p, struct stat_t64 *o) { struct stat64 s; int r = lstat64(p, &s); if (!r) fill_stat(o, &s); return r; }
int __fstatat64_time64(int dirfd, const char *p, struct stat_t64 *o, int flags)
{ struct stat64 s; int r = syscall(SYS_fstatat64, dirfd, p, &s, flags); if (!r) fill_stat(o, &s); return r; }

int __clock_gettime64(clockid_t clk, struct ts64 *o)
{ struct timespec t; int r = clock_gettime(clk, &t); if (!r) { o->sec = t.tv_sec; o->nsec = (int)t.tv_nsec; o->pad = 0; } return r; }
int __nanosleep64(const struct ts64 *req, struct ts64 *rem)
{
    struct timespec r = { (time_t)req->sec, req->nsec }, left;
    int rc = nanosleep(&r, &left);
    if (rc && rem) { rem->sec = left.tv_sec; rem->nsec = (int)left.tv_nsec; rem->pad = 0; }
    return rc;
}
int __gettimeofday64(struct tv64 *tv, void *tz)
{ struct timeval t; int r = gettimeofday(&t, (struct timezone *)tz); if (!r && tv) { tv->sec = t.tv_sec; tv->usec = t.tv_usec; } return r; }
int __utimensat64(int dirfd, const char *path, const struct ts64 *t, int flags)
{
    struct timespec k[2];
    if (t) for (int i = 0; i < 2; i++) { k[i].tv_sec = (time_t)t[i].sec; k[i].tv_nsec = t[i].nsec; }
    return syscall(SYS_utimensat, dirfd, path, t ? k : NULL, flags);
}
int __openat64_2(int dirfd, const char *path, int flags) { return openat64(dirfd, path, flags); }
