#!/bin/bash
#
# download-sf2.sh — Download all SF2 SoundFonts listed in sf2-sources.conf.
#
# Run this script once before your first build:
#   ./bin/download-sf2.sh
#
# SF2 files are placed in .cache/ in the project root.
# Xcode includes .cache/GeneralUser-GS.sf2 in the app bundle via Copy Bundle Resources.
# If that file is missing, the Xcode build will fail with a "file not found" error.
#
# The script is idempotent: files with correct checksums are skipped.
# On per-file failure, the script continues downloading remaining files
# and exits with non-zero status if any download failed.
#
# Dependencies: curl, shasum (stock macOS)

set -uo pipefail

# --- Configuration -----------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/sf2-sources.conf"
CACHE_DIR="${PROJECT_ROOT}/.cache"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "error: SF2 config file not found: ${CONFIG_FILE}" >&2
    echo "note: Ensure bin/sf2-sources.conf exists in the project." >&2
    exit 1
fi

# --- Helper functions --------------------------------------------------------

verify_checksum() {
    local file="$1"
    local expected="$2"
    local actual
    actual=$(shasum -a 256 "${file}" | awk '{print $1}')
    if [ "${actual}" = "${expected}" ]; then
        return 0
    else
        echo "  warning: Checksum mismatch for ${file}" >&2
        echo "    expected: ${expected}" >&2
        echo "    actual:   ${actual}" >&2
        return 1
    fi
}

# Download a single SF2 entry. Returns 0 on success, 1 on failure.
download_entry() {
    local section="$1"
    local url="$2"
    local filename="$3"
    local expected_sha256="$4"
    local cached_file="${CACHE_DIR}/${filename}"
    local temp_file="${CACHE_DIR}/${filename}.download"

    echo "--- [${section}] ${filename} ---"

    # Check if cached file exists and has correct checksum
    if [ -f "${cached_file}" ]; then
        if verify_checksum "${cached_file}" "${expected_sha256}"; then
            echo "  Up to date: ${cached_file}"
            return 0
        else
            echo "  Cached file has incorrect checksum. Re-downloading..."
            rm -f "${cached_file}"
        fi
    else
        echo "  No cached file found. Downloading..."
    fi

    # Download
    if ! curl -L -f --retry 3 --silent --show-error -o "${temp_file}" "${url}"; then
        echo "  error: Download failed for ${section}." >&2
        echo "  note: URL: ${url}" >&2
        echo "  note: You can manually place the file at ${cached_file}" >&2
        rm -f "${temp_file}"
        return 1
    fi

    # Verify download is not an HTML error page
    if file "${temp_file}" | grep -qi "HTML"; then
        rm -f "${temp_file}"
        echo "  error: Download returned an HTML page instead of an SF2 file." >&2
        echo "  note: The download URL for ${section} may have changed." >&2
        return 1
    fi

    mv "${temp_file}" "${cached_file}"
    echo "  Download complete."

    # Verify checksum
    if ! verify_checksum "${cached_file}" "${expected_sha256}"; then
        rm -f "${cached_file}"
        echo "  error: Downloaded file has incorrect checksum." >&2
        echo "  note: The expected checksum for ${section} in sf2-sources.conf may need updating." >&2
        return 1
    fi

    return 0
}

# --- Parse config and download -----------------------------------------------

mkdir -p "${CACHE_DIR}"

failure_count=0
success_count=0
current_section=""
url=""
filename=""
sha256=""

process_entry() {
    if [ -n "${current_section}" ] && [ -n "${url}" ] && [ -n "${filename}" ] && [ -n "${sha256}" ]; then
        if download_entry "${current_section}" "${url}" "${filename}" "${sha256}"; then
            success_count=$((success_count + 1))
        else
            failure_count=$((failure_count + 1))
        fi
    elif [ -n "${current_section}" ]; then
        echo "warning: Incomplete entry [${current_section}] — missing url, filename, or sha256. Skipping." >&2
        failure_count=$((failure_count + 1))
    fi
}

while IFS= read -r line || [ -n "${line}" ]; do
    # Strip leading/trailing whitespace
    line=$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip empty lines and comments
    [[ -z "${line}" || "${line}" == \#* ]] && continue

    # Section header
    if [[ "${line}" =~ ^\[([^]]+)\]$ ]]; then
        # Process previous entry before starting new section
        process_entry
        current_section="${BASH_REMATCH[1]}"
        url=""
        filename=""
        sha256=""
        continue
    fi

    # Key=value pairs
    case "${line}" in
        url=*)      url="${line#url=}" ;;
        filename=*) filename="${line#filename=}" ;;
        sha256=*)   sha256="${line#sha256=}" ;;
        # license= and attribution= are metadata only, not used by download
    esac
done < "${CONFIG_FILE}"

# Process the last entry
process_entry

# --- Summary -----------------------------------------------------------------

total=$((success_count + failure_count))
echo ""
echo "SF2 download complete: ${success_count}/${total} succeeded."

if [ "${failure_count}" -gt 0 ]; then
    echo "error: ${failure_count} download(s) failed." >&2
    exit 1
fi

exit 0
