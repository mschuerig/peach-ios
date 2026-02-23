#!/bin/bash
#
# download-sf2.sh — Download and cache the GeneralUser GS SF2 SoundFont for the Peach build.
#
# This script is invoked as an Xcode Run Script Build Phase. It:
#   1. Reads download configuration from tools/sf2-sources.json
#   2. Checks for a cached SF2 file at ~/.cache/peach/
#   3. Downloads the SF2 archive from the configured URL if needed
#   4. Extracts and verifies the SF2 against the expected SHA-256 checksum
#   5. Copies the verified SF2 into the app bundle's Resources directory
#
# Exit codes: non-zero fails the Xcode build.
# Dependencies: curl, shasum, unzip, python3 (all stock macOS)

set -euo pipefail

# --- Configuration -----------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/sf2-sources.json"
CACHE_DIR="${HOME}/.cache/peach"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "error: SF2 config file not found: ${CONFIG_FILE}" >&2
    echo "note: Ensure tools/sf2-sources.json exists in the project root." >&2
    exit 1
fi

# Parse JSON config using python3 (stock macOS)
DOWNLOAD_URL=$(/usr/bin/python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(c['url'])" "${CONFIG_FILE}")
ARCHIVE_PATH=$(/usr/bin/python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(c['archive_path'])" "${CONFIG_FILE}")
SF2_FILENAME=$(/usr/bin/python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(c['filename'])" "${CONFIG_FILE}")
EXPECTED_SHA256=$(/usr/bin/python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(c['sha256'])" "${CONFIG_FILE}")

CACHED_SF2="${CACHE_DIR}/${SF2_FILENAME}"

# --- Helper functions --------------------------------------------------------

verify_checksum() {
    local file="$1"
    local actual
    actual=$(shasum -a 256 "${file}" | awk '{print $1}')
    if [ "${actual}" = "${EXPECTED_SHA256}" ]; then
        return 0
    else
        echo "warning: Checksum mismatch for ${file}" >&2
        echo "  expected: ${EXPECTED_SHA256}" >&2
        echo "  actual:   ${actual}" >&2
        return 1
    fi
}

download_and_extract() {
    local temp_zip="${CACHE_DIR}/${SF2_FILENAME}.download.zip"
    local temp_extract="${CACHE_DIR}/extract_tmp"

    # Clean up any previous partial downloads
    rm -f "${temp_zip}"
    rm -rf "${temp_extract}"

    echo "Downloading SF2 archive..."
    if ! curl -L -f --retry 3 --silent --show-error -o "${temp_zip}" "${DOWNLOAD_URL}"; then
        rm -f "${temp_zip}"
        echo "error: Download failed. Check your network connection or manually place the file at ${CACHED_SF2}" >&2
        echo "note: Download URL: ${DOWNLOAD_URL}" >&2
        exit 1
    fi

    # Verify we got an actual zip, not an HTML error page
    if file "${temp_zip}" | grep -q "HTML"; then
        rm -f "${temp_zip}"
        echo "error: Download returned an HTML page instead of a ZIP archive." >&2
        echo "note: The download URL may have changed. Check tools/sf2-sources.json." >&2
        echo "note: You can manually download and place the file at ${CACHED_SF2}" >&2
        exit 1
    fi

    # Extract the SF2 from the archive
    echo "Extracting ${ARCHIVE_PATH}..."
    mkdir -p "${temp_extract}"
    if ! unzip -o -q "${temp_zip}" "${ARCHIVE_PATH}" -d "${temp_extract}"; then
        rm -f "${temp_zip}"
        rm -rf "${temp_extract}"
        echo "error: Failed to extract ${ARCHIVE_PATH} from downloaded archive." >&2
        exit 1
    fi

    # Move extracted SF2 to cache location
    mv "${temp_extract}/${ARCHIVE_PATH}" "${CACHED_SF2}"

    # Clean up temp files
    rm -f "${temp_zip}"
    rm -rf "${temp_extract}"

    echo "Download and extraction complete."
}

# --- Main --------------------------------------------------------------------

mkdir -p "${CACHE_DIR}"

# Check if cached file exists and has correct checksum
if [ -f "${CACHED_SF2}" ]; then
    if verify_checksum "${CACHED_SF2}"; then
        echo "Using cached SF2: ${CACHED_SF2}"
    else
        echo "Cached file has incorrect checksum. Re-downloading..."
        rm -f "${CACHED_SF2}"
        download_and_extract

        if ! verify_checksum "${CACHED_SF2}"; then
            rm -f "${CACHED_SF2}"
            echo "error: Downloaded file still has incorrect checksum after re-download." >&2
            echo "note: The expected checksum in tools/sf2-sources.json may need updating." >&2
            echo "note: You can manually place the correct file at ${CACHED_SF2}" >&2
            exit 1
        fi
    fi
else
    echo "No cached SF2 found. Downloading..."
    download_and_extract

    if ! verify_checksum "${CACHED_SF2}"; then
        rm -f "${CACHED_SF2}"
        echo "error: Downloaded file has incorrect checksum." >&2
        echo "note: The expected checksum in tools/sf2-sources.json may need updating." >&2
        echo "note: You can manually place the correct file at ${CACHED_SF2}" >&2
        exit 1
    fi
fi

# Copy to build output (Xcode environment variables)
if [ -n "${BUILT_PRODUCTS_DIR:-}" ] && [ -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]; then
    DEST_DIR="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
    mkdir -p "${DEST_DIR}"
    cp "${CACHED_SF2}" "${DEST_DIR}/${SF2_FILENAME}"
    echo "Copied SF2 to app bundle: ${DEST_DIR}/${SF2_FILENAME}"
else
    # Running outside Xcode (e.g., manual invocation)
    echo "note: BUILT_PRODUCTS_DIR not set — skipping copy to app bundle (not running in Xcode build)."
fi

echo "SF2 setup complete."
