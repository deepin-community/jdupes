/* jdupes file matching functions
 * This file is part of jdupes; see jdupes.c for license information */

#ifndef JDUPES_MATCH_H
#define JDUPES_MATCH_H

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>
#include "jdupes.h"

/* registerfile() direction options */
enum tree_direction { NONE, LEFT, RIGHT };

void registerpair(file_t **matchlist, file_t *newmatch, int (*comparef)(file_t *f1, file_t *f2));
void registerfile(filetree_t * restrict * const restrict nodeptr, const enum tree_direction d, file_t * const restrict file);
file_t **checkmatch(filetree_t * restrict tree, file_t * const restrict file);
int confirmmatch(FILE * const restrict file1, FILE * const restrict file2, const off_t size);

#ifdef __cplusplus
}
#endif

#endif /* JDUPES_MATCH_H */
