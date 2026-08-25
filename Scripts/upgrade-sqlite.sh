#!/usr/bin/env bash
# Replace the vendored SQLite amalgamation with a different version.
#
# Usage:
#   ./Scripts/upgrade-sqlite.sh 3.53.1
#   ./Scripts/upgrade-sqlite.sh 3.53.1 /path/to/extracted/amalgamation
#
# This fork compiles its own SQLite because Apple ships the system library
# without SQLITE_ENABLE_PREUPDATE_HOOK. The compile options live in
# Package.swift, not here. This script moves the source only.
#
# The copied files need no patch. sqlite3.c stays byte for byte the sqlite.org
# release, and Sources/GRDBSQLite/amalgamation.c is the translation unit that
# includes it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${PACKAGE_DIR}/Sources/GRDBSQLite"
INCLUDE_DIR="${TARGET_DIR}/include"

usage() {
    echo "usage: $0 <version> [source-directory]" >&2
    echo "  e.g. $0 3.53.1" >&2
    exit 1
}

[[ $# -ge 1 && $# -le 2 ]] || usage

VERSION="$1"
SOURCE_DIR="${2:-}"

[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "error: version must read X.Y.Z, for example 3.53.1" >&2
    exit 1
}

# SQLite encodes a download name as X*1000000 + Y*10000 + Z*100, zero padded.
IFS='.' read -r MAJOR MINOR PATCH <<< "${VERSION}"
VERSION_CODE="$(( MAJOR * 1000000 + MINOR * 10000 + PATCH * 100 ))"
printf -v VERSION_CODE_PADDED '%07d' "${VERSION_CODE}"

read_installed_version() {
    local header="${INCLUDE_DIR}/sqlite3.h"
    [[ -f "${header}" ]] || { echo "none"; return; }
    local line
    line="$(grep -m1 '#define SQLITE_VERSION ' "${header}")" || { echo "unknown"; return; }
    line="${line#*\"}"
    echo "${line%%\"*}"
}

installed="$(read_installed_version)"
echo "installed: ${installed}"
echo "requested: ${VERSION}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

if [[ -z "${SOURCE_DIR}" ]]; then
    ARCHIVE="sqlite-autoconf-${VERSION_CODE_PADDED}.tar.gz"
    # SQLite files a release under the year it shipped. Try recent years, newest
    # first, because the script cannot know the year from the version alone.
    for year in 2026 2025 2024 2023; do
        URL="https://sqlite.org/${year}/${ARCHIVE}"
        if curl -fsSL --max-time 120 -o "${WORK_DIR}/${ARCHIVE}" "${URL}"; then
            echo "downloaded ${URL}"
            SOURCE_DIR="${WORK_DIR}/sqlite-autoconf-${VERSION_CODE_PADDED}"
            tar -xzf "${WORK_DIR}/${ARCHIVE}" -C "${WORK_DIR}"
            break
        fi
    done
    [[ -n "${SOURCE_DIR}" ]] || {
        echo "error: no download found for ${ARCHIVE}" >&2
        echo "       pass an extracted amalgamation directory as the second argument" >&2
        exit 1
    }
fi

for file in sqlite3.c sqlite3.h sqlite3ext.h; do
    [[ -f "${SOURCE_DIR}/${file}" ]] || {
        echo "error: ${SOURCE_DIR}/${file} is missing" >&2
        exit 1
    }
done

mkdir -p "${INCLUDE_DIR}"
cp "${SOURCE_DIR}/sqlite3.c" "${TARGET_DIR}/sqlite3.c"
cp "${SOURCE_DIR}/sqlite3.h" "${SOURCE_DIR}/sqlite3ext.h" "${INCLUDE_DIR}/"

installed="$(read_installed_version)"
echo "installed: ${installed}"
echo
echo "next: run swift test"
