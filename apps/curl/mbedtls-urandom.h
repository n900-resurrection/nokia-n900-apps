/* Make mbedTLS read its entropy from /dev/urandom instead of /dev/random. Pulled in with -include.
 *
 * Since 3.6 mbedTLS reads /dev/random when the getrandom() system call is not available. The
 * Maemo 5 kernel (2.6.28) has no getrandom(), and its /dev/random blocks for a very long time on
 * an idle device: every program using mbedTLS (curl --version included) then hangs at start-up.
 * Upstream documents this: "may block needlessly on Linux <= 5.6".
 *
 * Trade-off: /dev/urandom never blocks. The kernel entropy pool of a running phone has been
 * seeded by interrupts and user input long before curl is started, so this is acceptable here.
 * Do NOT use this in anything that runs very early at boot.
 */
#ifndef N900_MBEDTLS_URANDOM_H
#define N900_MBEDTLS_URANDOM_H

#define MBEDTLS_PLATFORM_DEV_RANDOM "/dev/urandom"

#endif
