/* Snapshot I/O is not called by the timer replay. Fail rather than silently
 * pretending to restore a snapshot if that ever changes. */
#ifndef CIA_TEST_SNAPSHOT_H
#define CIA_TEST_SNAPSHOT_H
#include <stdlib.h>
typedef struct snapshot_module_s { int unused; } snapshot_module_t;
#define SMW_W(module, value) abort()
#define SMR_W(module, value) abort()
#endif
