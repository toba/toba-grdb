# Project: Toba GRDB

An adaptation of [groue/GRDB.swift](https://github.com/groue/GRDB.swift). One library product,
`GRDB`, over the `GRDB` and `GRDBSQLite` targets. The main patch compiles the SQLite amalgamation in
`Sources/GRDBSQLite/` instead of linking the system library, because Apple ships SQLite without
`SQLITE_ENABLE_PREUPDATE_HOOK`.

## An adaptation, not a tracking fork

This repository owns its code. It does not preserve upstream's shape for the sake of an easy merge.

- **Rewrite freely.** Reformat a file, rename a symbol, restructure a type, delete a branch that
  serves a platform this package does not target. A wide diff against upstream is an accepted cost,
  not a reason to refuse an improvement.
- **Run `sm format` on every Swift file you edit.** It rewrites the whole file rather than the
  edited region. That is the intended result here.
- **Never argue against a change on merge cost alone.** Merging an upstream release still works, and
  the steps are in `README.md`. A conflict is expected work, not a defect.

The one thing that does not change is the deviation record.

## Record every deviation in `README.md`

A section per deviation, above the upstream README. Each one states four things:

1. What upstream does, with the file and the symbol, and the release the reading came from.
2. What this code does instead.
3. Why, in terms of the defect or the requirement that forced it. A preference is not a reason.
4. Where the test is that holds the deviation in place.

Say which kind it is. An *additive* deviation adds API and changes no upstream behavior. A
*behavioral* deviation changes what existing code does, and it carries the higher bar: name what
breaks without it.

A whole-file reformat needs no section. A change to what the code does needs one.

## Rules

- **Build and test through xc-swift** — `swift_package_build`, `swift_package_test`,
  `swift_diagnostics`. Build only when the user asks.
- **Never write an `@available` attribute that names an OS version.** The target holds none. The
  vendored SQLite sets the feature floor, and `sqlite3.h` declares `SQLITE_VERSION "3.53.4"` on every
  platform. The platform floor covers every standard-library type the source reaches.
- **`Sources/GRDBSQLite/sqlite3.c` stays byte for byte the sqlite.org release.** `amalgamation.c` is
  the one compiled source and it includes `sqlite3.c`. `Scripts/upgrade-sqlite.sh` copies a newer
  amalgamation in.
- **Refuse anything that restores `.gitmodules` or the `SQLiteCustom/src` gitlink.** SwiftPM runs a
  recursive submodule init on every checkout, and that pulled 111 MB this build never reads.
- **The `#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC` branches are dead weight.** The SwiftPM build
  always takes the `#else` branch. Collapsing one is welcome. Test both sides before you do, because
  the Xcode projects still define those flags.

## Environment

Swift 6.4 | tools version 6.4 | OS 27 floor on iOS, macOS, tvOS, watchOS and visionOS | sources at
`GRDB` | tests at `Tests/GRDBTests` | Jig project **GRDB Fork** | upstream remote `upstream`
