/* Stand-in for <tgmath.h> of glibc 2.5: its type-generic macros need a GCC extension that GCC 13 rejects
 * ("variable or field '__tgmres' declared void"). The puzzles only call the double functions (sqrt, fabs, sin ...), so plain <math.h> is enough
 * (a float argument is promoted to double, as it always was in C without tgmath). */
#ifndef MAEMO_TGMATH_SHIM_H
#define MAEMO_TGMATH_SHIM_H
#include <math.h>
#endif
