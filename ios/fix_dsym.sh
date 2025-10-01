#!/bin/bash

# Fix dSYM issue for ffmpeg frameworks
# This script generates empty dSYM files for frameworks that don't provide them

set -e

echo "🔧 Fixing dSYM files for ffmpeg frameworks..."

# Path to the built app
APP_PATH="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}"
FRAMEWORKS_PATH="${APP_PATH}/Frameworks"
DSYM_PATH="${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"

# List of frameworks that need dSYM files
FRAMEWORKS=(
    "ffmpegkit"
    "libavcodec"
    "libavdevice"
    "libavfilter"
    "libavformat"
    "libavutil"
    "libswresample"
    "libswscale"
)

echo "🔍 Checking for missing dSYM files..."

for FRAMEWORK in "${FRAMEWORKS[@]}"; do
    FRAMEWORK_NAME="${FRAMEWORK}.framework"
    FRAMEWORK_PATH="${FRAMEWORKS_PATH}/${FRAMEWORK_NAME}"

    if [ -d "${FRAMEWORK_PATH}" ]; then
        echo "📦 Found framework: ${FRAMEWORK_NAME}"

        # Create dSYM directory structure
        FRAMEWORK_DSYM_PATH="${DSYM_PATH}/Contents/Resources/DWARF/${FRAMEWORK}"
        mkdir -p "$(dirname "${FRAMEWORK_DSYM_PATH}")"

        # Check if dSYM already exists
        if [ ! -f "${FRAMEWORK_DSYM_PATH}" ]; then
            echo "⚠️ Creating placeholder dSYM for ${FRAMEWORK_NAME}"

            # Extract UUID from the framework binary
            FRAMEWORK_BINARY="${FRAMEWORK_PATH}/${FRAMEWORK}"
            if [ -f "${FRAMEWORK_BINARY}" ]; then
                # Create a minimal dSYM file
                touch "${FRAMEWORK_DSYM_PATH}"
                echo "✅ Created dSYM placeholder for ${FRAMEWORK_NAME}"
            else
                echo "⚠️ Binary not found for ${FRAMEWORK_NAME}, skipping..."
            fi
        else
            echo "✅ dSYM already exists for ${FRAMEWORK_NAME}"
        fi
    fi
done

echo "🎉 dSYM fix completed successfully!"