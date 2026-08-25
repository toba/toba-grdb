/*
** The one translation unit that compiles the vendored SQLite amalgamation.
**
** sqlite3.c defines MIN and MAX before it imports the first Darwin module, and
** sys/param.h inside that module defines both names again. Clang then reports
** every later use as an ambiguous expansion, 116 times in one build. The two
** definitions agree, so the warning reports no defect.
**
** sqlite3.c also narrows a 64 bit integer to a 32 bit one in 136 places, and
** each one is deliberate. SQLite bounds the value before it converts, so the
** conversion loses nothing.
**
** Both pragmas sit here rather than in sqlite3.c so that file stays byte for
** byte the sqlite.org release, which is what upgrade-sqlite.sh copies in. A
** cSetting cannot carry either flag: only unsafeFlags takes a -Wno- option, and
** SwiftPM refuses a package that declares unsafeFlags to a consumer resolving
** it by version.
*/
#pragma clang diagnostic ignored "-Wambiguous-macro"
#pragma clang diagnostic ignored "-Wshorten-64-to-32"

#include "sqlite3.c"  // IWYU pragma: keep
