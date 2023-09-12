#include <sys/types.h>
#include <sys/syscall.h>

#include "dat.h"


int
segflush(void *a, ulong n)
{
// TODO before JIT implementation
	if(n)
		__builtin___clear_cache(a, a+n);

	return 0;
}
