/* Signal handler/interruption functions
 * This file is part of jdupes; see jdupes.c for license information */

#ifndef JDUPES_INTERRUPT_H
#define JDUPES_INTERRUPT_H

#ifdef __cplusplus
extern "C" {
#endif

#include "jdupes.h"

extern int interrupt;

void catch_interrupt(const int signum);
void start_progress_alarm(void);
void stop_progress_alarm(void);
#ifdef ON_WINDOWS
#define check_sigusr1()
#else
void catch_sigusr1(const int signum);
void catch_sigalrm(const int signum);
void check_sigusr1(void);
#endif /* ON_WINDOWS */

#ifdef __cplusplus
}
#endif

#endif /* JDUPES_INTERRUPT_H */
