#!/bin/bash
# Script to switch Skalp to DEV MODE (Source Linking)

PLUGINS_DIR="$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins"
SOURCE_DIR="/Users/guywydouw/Dropbox/Guy/SourceTree_repo/Skalp 2026/_src"
TARGET_LINK="$PLUGINS_DIR/Skalp_Skalp"
BACKUP_DIR="$PLUGINS_DIR/Skalp_Skalp_BAK"

echo ">>> Switching Skalp to Developer Mode..."

# 1. Backup existing installation
if [ -d "$TARGET_LINK" ] && [ ! -L "$TARGET_LINK" ]; then
    echo "Backing up existing installation to $BACKUP_DIR..."
    rm -rf "$BACKUP_DIR"
    mv "$TARGET_LINK" "$BACKUP_DIR"
else
    echo "Warning: No standard installation found or already linked."
    if [ ! -d "$BACKUP_DIR" ]; then
       echo "Creating backup dir from current target link content check..."
       # safety check
    fi
fi

# 2. Copy Binaries from Backup to Source
# We need SkalpC.mac and lib_mac folder in _src because we are running from it.
echo "Copying binaries to _src..."
if [ -d "$BACKUP_DIR" ]; then
    cp "$BACKUP_DIR/SkalpC.mac" "$SOURCE_DIR/"
    cp -R "$BACKUP_DIR/lib_mac" "$SOURCE_DIR/"
    # Also copy any other resources that might be missing from _src if applicable
    # cp -R "$BACKUP_DIR/resources" "$SOURCE_DIR/" 
    echo "Binaries copied."
else
    echo "Error: Backup directory missing. Cannot copy binaries. Assuming they exist in _src."
fi

# 3. Create Symlink
echo "Creating Symlink..."
rm -rf "$TARGET_LINK"
ln -s "$SOURCE_DIR" "$TARGET_LINK"

echo ">>> DONE. Setup Complete."
echo "1. Restart SketchUp."
echo "2. Use 'Skalp.reload' in Ruby Console to reload changes."
