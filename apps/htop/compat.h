/* Shims for building against glibc 2.5 (Maemo 5, kernel 2.6.28). Pulled in with -include.
 *
 * Do NOT include anything here. Headers included before the source file fix the feature test
 * macros (_GNU_SOURCE and friends); the build then fails with errors such as
 * "invalid use of undefined type struct timespec".
 */
#ifndef N900_COMPAT_H
#define N900_COMPAT_H

/* The glibc 2.5 headers lack O_CLOEXEC, but kernel 2.6.23+ supports it. The value comes from
 * asm-generic/fcntl.h (the same on ARM). A kernel that did not know the flag would ignore it. */
#ifndef O_CLOEXEC
#define O_CLOEXEC 02000000
#endif

#endif
