#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marcus Baw
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

readonly repository_url="${BAKEDOCS_REPOSITORY_URL:-https://github.com/pacharanero/bakedocs}"
readonly release_base_url="${BAKEDOCS_RELEASE_BASE_URL:-$repository_url/releases/download}"
prefix=""
requested_version="${BAKEDOCS_VERSION:-}"
operation="install"
temp_dir=""

usage() {
  cat <<'EOF'
Usage: install.sh [--version <VERSION>] [--prefix <PATH>] [--uninstall]

Download and verify a bakedocs release before installing it under $HOME/.local
by default. No package manager or sudo command is invoked.
EOF
}

fail() {
  printf 'bakedocs bootstrap: %s\n' "$1" >&2
  exit "${2:-1}"
}

cleanup() {
  [[ -z "$temp_dir" || ! -d "$temp_dir" ]] || rm -rf "$temp_dir"
}

download() {
  local url="$1"
  local output="$2"
  local maximum_size="$3"
  local protocol
  local size

  case "$url" in
    https://*) protocol='=https' ;;
    file://*)
      [[ "${BAKEDOCS_ALLOW_FILE_URLS:-}" == 1 ]] || fail 'file downloads are disabled'
      protocol='=file'
      ;;
    *) fail "release URL must use HTTPS: $url" ;;
  esac

  curl --proto "$protocol" --tlsv1.2 --fail --location --silent --show-error \
    --max-filesize "$maximum_size" --output "$output" "$url"
  size="$(wc -c < "$output")"
  ((size <= maximum_size)) || fail "download exceeds the $maximum_size byte limit: $url"
}

latest_version() {
  local effective_url
  local tag

  [[ "$repository_url" == https://* ]] || fail 'latest-version discovery requires an HTTPS repository URL'
  effective_url="$(curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
    --output /dev/null --write-out '%{url_effective}' "$repository_url/releases/latest")"
  tag="${effective_url##*/}"
  [[ "$tag" == v* ]] || fail 'latest release did not resolve to a version tag'
  printf '%s\n' "${tag#v}"
}

sha256_file() {
  local output

  if command -v sha256sum >/dev/null 2>&1; then
    output="$(sha256sum "$1")"
  elif command -v shasum >/dev/null 2>&1; then
    output="$(shasum -a 256 "$1")"
  else
    fail 'sha256sum or shasum is required to verify the release'
  fi
  printf '%s\n' "${output%%[[:space:]]*}"
}

dependency_guidance() {
  local platform="$1"

  printf '\nRendering dependencies are not installed automatically.\n' >&2
  case "$platform" in
    linux)
      printf '%s\n' \
        'Pandoc 3.7.1+: use an official package from https://pandoc.org/installing.html; distribution packages may be older.' \
        'Chromium: use your distribution package, such as apt install chromium, dnf install chromium, or pacman -S chromium.' \
        'Poppler: use apt install poppler-utils, dnf install poppler-utils, or pacman -S poppler.' >&2
      ;;
    macos)
      printf '%s\n' \
        'Pandoc 3.7.1+: brew install pandoc' \
        'Chromium: brew install --cask chromium' \
        'Poppler: brew install poppler' \
        'Bash 4+: brew install bash, then ensure Homebrew bin precedes /bin on PATH.' >&2
      ;;
  esac
  printf 'Run bakedocs check after installing the dependencies.\n' >&2
}

while (($#)); do
  case "$1" in
    --version)
      (($# >= 2)) || fail '--version requires a value' 2
      requested_version="$2"
      shift 2
      ;;
    --version=*)
      requested_version="${1#*=}"
      [[ -n "$requested_version" ]] || fail '--version requires a non-empty value' 2
      shift
      ;;
    --prefix)
      (($# >= 2)) || fail '--prefix requires a path' 2
      prefix="$2"
      [[ -n "$prefix" ]] || fail '--prefix requires a non-empty path' 2
      shift 2
      ;;
    --prefix=*)
      prefix="${1#*=}"
      [[ -n "$prefix" ]] || fail '--prefix requires a non-empty path' 2
      shift
      ;;
    --uninstall)
      operation="uninstall"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) fail "unknown option: $1" 2 ;;
  esac
done

command -v curl >/dev/null 2>&1 || fail 'curl is required to download the release'
command -v tar >/dev/null 2>&1 || fail 'tar is required to extract the release'

platform="${BAKEDOCS_PLATFORM:-}"
if [[ -z "$platform" ]]; then
  case "$(uname -s)" in
    Linux) platform="linux" ;;
    Darwin) platform="macos" ;;
    CYGWIN*|MINGW*|MSYS*) fail 'native Windows is not supported; install bakedocs inside WSL' ;;
    *) fail 'supported bootstrap platforms are Linux and macOS' ;;
  esac
fi
[[ "$platform" == linux || "$platform" == macos ]] || fail "unsupported bootstrap platform: $platform"
if ((BASH_VERSINFO[0] < 4)); then
  if [[ "$platform" == macos ]]; then
    fail 'Bash 4 or later is required; run brew install bash, then rerun this installer with the Homebrew bash executable'
  fi
  fail 'Bash 4 or later is required'
fi

if [[ -z "$requested_version" ]]; then
  requested_version="$(latest_version)"
fi
[[ "$requested_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || fail "invalid release version: $requested_version" 2

archive_name="bakedocs-$requested_version.tar.gz"
release_url="$release_base_url/v$requested_version"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bakedocs-bootstrap.XXXXXXXX")"
trap cleanup EXIT
archive="$temp_dir/$archive_name"
checksums="$temp_dir/SHA256SUMS"
listing="$temp_dir/archive-list.txt"
verbose_listing="$temp_dir/archive-verbose-list.txt"

download "$release_url/$archive_name" "$archive" 10485760
download "$release_url/SHA256SUMS" "$checksums" 1048576

expected_checksum=""
checksum_matches=0
while read -r checksum filename extra; do
  filename="${filename#\*}"
  if [[ "$filename" == "$archive_name" && -z "${extra:-}" ]]; then
    expected_checksum="$checksum"
    checksum_matches=$((checksum_matches + 1))
  fi
done < "$checksums"
((checksum_matches == 1)) || fail "SHA256SUMS must contain exactly one entry for $archive_name"
[[ "$expected_checksum" =~ ^[0-9a-fA-F]{64}$ ]] || fail "SHA256SUMS has no valid entry for $archive_name"
actual_checksum="$(sha256_file "$archive")"
actual_checksum="$(printf '%s' "$actual_checksum" | tr 'A-F' 'a-f')"
expected_checksum="$(printf '%s' "$expected_checksum" | tr 'A-F' 'a-f')"
[[ "$actual_checksum" == "$expected_checksum" ]] || fail "checksum verification failed for $archive_name"

(ulimit -f 2048; tar -tzf "$archive" > "$listing") || fail 'release archive listing failed or exceeded its size limit'
(ulimit -f 2048; tar -tvzf "$archive" > "$verbose_listing") || fail 'release archive type listing failed or exceeded its size limit'
package_root="bakedocs-$requested_version"
found_entry=false
declare -A seen_entries=()
while IFS= read -r entry || [[ -n "$entry" ]]; do
  [[ "$entry" == "$package_root" || "$entry" == "$package_root/"* ]] || fail "release archive contains an unexpected path: $entry"
  [[ -z "${seen_entries[$entry]+present}" ]] || fail "release archive contains a duplicate entry: $entry"
  seen_entries["$entry"]=true
  case "$entry" in
    "$package_root"/|\
    "$package_root"/bakedocs|\
    "$package_root"/LICENSE|\
    "$package_root"/filters/|\
    "$package_root"/filters/metadata-interpolation.lua|\
    "$package_root"/filters/bitwarden.lua|\
    "$package_root"/filters/resources.lua|\
    "$package_root"/s/|\
    "$package_root"/s/install|\
    "$package_root"/s/uninstall|\
    "$package_root"/styles/|\
    "$package_root"/styles/document.css|\
    "$package_root"/styles/reveal.css|\
    "$package_root"/templates/|\
    "$package_root"/templates/document.html|\
    "$package_root"/templates/reveal.html) ;;
    *) fail "release archive contains an unexpected payload entry: $entry" ;;
  esac
  found_entry=true
done < "$listing"
[[ "$found_entry" == true ]] || fail 'release archive is empty'
while IFS= read -r entry || [[ -n "$entry" ]]; do
  case "${entry:0:1}" in
    -|d) ;;
    *) fail 'release archive contains a non-file entry' ;;
  esac
done < "$verbose_listing"

(ulimit -f 20480; tar -xzf "$archive" -C "$temp_dir") || fail 'release archive extraction failed or exceeded its file-size limit'
extracted="$temp_dir/$package_root"
[[ -x "$extracted/bakedocs" && -x "$extracted/s/install" && -x "$extracted/s/uninstall" && -s "$extracted/LICENSE" ]] || fail 'release payload is incomplete'
[[ "$("$extracted/bakedocs" version)" == "bakedocs $requested_version" ]] || fail 'release payload version does not match its archive'

action=("$extracted/s/$operation")
[[ -z "$prefix" ]] || action+=(--prefix "$prefix")
"${action[@]}"
[[ "$operation" == uninstall ]] || dependency_guidance "$platform"
