#!/bin/bash
# Script to restore Skalp from Backup (remove dev link)

PLUGINS_DIR="$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins"
TARGET_LINK="$PLUGINS_DIR/Skalp_Skalp"
BACKUP_DIR="$PLUGINS_DIR/Skalp_Skalp_BAK"

echo ">>> Restoring Skalp from Backup..."

# 1. Remove Symlink
if [ -L "$TARGET_LINK" ]; then
    echo "Removing symlink..."
    rm "$TARGET_LINK"
else
    echo "Warning: Target is not a symlink or missing. Checking if it's a directory..."
    if [ -d "$TARGET_LINK" ]; then
       echo "Target is a directory. Assuming manual intervention or fastbuild already ran? Doing nothing to target."
       # We should not delete a real directory unless we are sure it's wrong.
       # But if BACKUP exists, we should probably prefer BACKUP if we want to restore previous state.
       # However, creating a clean state for fastbuild is the goal.
       # Fastbuild OVERWRITES target usually?
       # Let's just ensure BACKUP is restored if it exists and TARGET was a link.
    fi
fi

# 2. Restore Backup
if [ -d "$BACKUP_DIR" ]; then
    if [ ! -e "$TARGET_LINK" ]; then
        echo "Moving backup back to target..."
        mv "$BACKUP_DIR" "$TARGET_LINK"
    else
        echo "Target exists. Leaving backup at $BACKUP_DIR."
    fi
else
    echo "No backup found."
fi

echo ">>> Restore finish. Ready for Fastbuild."
