/* Declarations for C++ on glibc 2.5 (Maemo 5): libstdc++'s <cstdlib> does "using ::aligned_alloc" etc., and the old <stdlib.h> lacks them.
 * Pulled in with -include by scripts/maemo-g++; the definitions are in scripts/maemo-cxx-compat.c. Only <stddef.h> here (see maemo-compat.h). */
#ifndef N900_CXX_COMPAT_H
#define N900_CXX_COMPAT_H
#include <stddef.h>
#ifdef __cplusplus
#include <time.h>      /* g++ defines _GNU_SOURCE itself, so including system headers early is safe in C++ */
#include <pthread.h>
extern "C" {
void *aligned_alloc(size_t, size_t) throw();
int at_quick_exit(void (*)(void)) throw();
void quick_exit(int) throw() __attribute__((noreturn));
long double acoshl(long double) throw();
long double asinhl(long double) throw();
long double atanhl(long double) throw();
long double cbrtl(long double) throw();
long double erfl(long double) throw();
long double erfcl(long double) throw();
long double exp2l(long double) throw();
long double expm1l(long double) throw();
long double lgammal(long double) throw();
long double log1pl(long double) throw();
long double log2l(long double) throw();
long double logbl(long double) throw();
long double nearbyintl(long double) throw();
long double rintl(long double) throw();
long double roundl(long double) throw();
long double truncl(long double) throw();
long double tgammal(long double) throw();
long double copysignl(long double, long double) throw();
long double fdiml(long double, long double) throw();
long double fmaxl(long double, long double) throw();
long double fminl(long double, long double) throw();
long double hypotl(long double, long double) throw();
long double nextafterl(long double, long double) throw();
long double nexttowardl(long double, long double) throw();
long double remainderl(long double, long double) throw();
long double fmal(long double, long double, long double) throw();
int ilogbl(long double) throw();
long long llrintl(long double) throw();
long long llroundl(long double) throw();
long lrintl(long double) throw();
long lroundl(long double) throw();
long double nanl(const char *) throw();
long double remquol(long double, long double, int *) throw();
long double scalblnl(long double, long) throw();
long double scalbnl(long double, int) throw();
int timespec_get(struct timespec *, int) throw();
int pthread_cond_clockwait(pthread_cond_t *, pthread_mutex_t *, clockid_t, const struct timespec *) throw();
int pthread_mutex_clocklock(pthread_mutex_t *, clockid_t, const struct timespec *) throw();
}
#endif
#endif
