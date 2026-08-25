/*
** The one translation unit that compiles the vendored SQLite amalgamation.
**
** sqlite3.c defines MIN and MAX before it imports the first Darwin module, and
** sys/param.h inside that module defines both names again. Clang then reports
** every later use as an ambiguous expansion, 116 times in one build. The two
** definitions agree, so the warning reports no defect.
**
** The pragma sits here rather than in sqlite3.c so that file stays byte for
** byte the sqlite.org release, which is what upgrade-sqlite.sh copies in.
*/
#pragma clang diagnostic ignored "-Wambiguous-macro"

#include "sqlite3.c"  // IWYU pragma: keep
