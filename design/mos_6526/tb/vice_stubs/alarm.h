#ifndef CIA_TEST_ALARM_H
#define CIA_TEST_ALARM_H
#include "types.h"
typedef struct { CLOCK scheduled; } alarm_t;
static inline void alarm_set(alarm_t *alarm, CLOCK clock) { alarm->scheduled=clock; }
static inline void alarm_unset(alarm_t *alarm) { alarm->scheduled=CLOCK_MAX; }
#endif
