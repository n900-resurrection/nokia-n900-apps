/* Byte-order helpers missing in glibc 2.5 (htobe32, letoh32 ... came with glibc 2.9). ARM Maemo 5 is little-endian. */
#ifndef N900_ENDIAN_COMPAT_H
#define N900_ENDIAN_COMPAT_H
#define N900_BSWAP16(x) ((unsigned short)__builtin_bswap16(x))
#define N900_BSWAP32(x) ((unsigned int)__builtin_bswap32(x))
#define N900_BSWAP64(x) ((unsigned long long)__builtin_bswap64(x))
#ifndef htole16
#define htole16(x) (x)
#define htole32(x) (x)
#define htole64(x) (x)
#define le16toh(x) (x)
#define le32toh(x) (x)
#define le64toh(x) (x)
#endif
#ifndef letoh16
#define letoh16(x) (x)
#define letoh32(x) (x)
#define letoh64(x) (x)
#endif
#ifndef htobe16
#define htobe16(x) N900_BSWAP16(x)
#define htobe32(x) N900_BSWAP32(x)
#define htobe64(x) N900_BSWAP64(x)
#endif
#ifndef be16toh
#define be16toh(x) N900_BSWAP16(x)
#define be32toh(x) N900_BSWAP32(x)
#define be64toh(x) N900_BSWAP64(x)
#endif
#ifndef betoh16
#define betoh16(x) N900_BSWAP16(x)
#define betoh32(x) N900_BSWAP32(x)
#define betoh64(x) N900_BSWAP64(x)
#endif
#endif
