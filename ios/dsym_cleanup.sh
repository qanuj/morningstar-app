#!/bin/bash

# dSYM Cleanup Script for ffmpeg frameworks
# This script removes dSYM references for frameworks that don't provide them

echo "🧹 Cleaning up dSYM references for ffmpeg frameworks..."

# Get the dSYM path
DSYM_PATH="${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"

if [ -d "$DSYM_PATH" ]; then
    echo "📂 Found dSYM bundle at: $DSYM_PATH"

    # List of problematic frameworks
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

    for FRAMEWORK in "${FRAMEWORKS[@]}"; do
        DSYM_FILE="${DSYM_PATH}/Contents/Resources/DWARF/${FRAMEWORK}"
        if [ -f "$DSYM_FILE" ]; then
            echo "🗑️ Removing problematic dSYM: $FRAMEWORK"
            rm -f "$DSYM_FILE"
        fi
    done

    echo "✅ dSYM cleanup completed"
else
    echo "⚠️ No dSYM bundle found, skipping cleanup"
fi