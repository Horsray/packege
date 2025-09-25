#!/bin/bash
set -e

APP_NAME="__APP_NAME__"

SRC="/Library/Application Support/${APP_NAME}-payload/${APP_NAME}"

if [ ! -d "$SRC" ]; then
  echo "ERROR: source not found: $SRC"
  exit 1
fi

shopt -s nullglob
for PSPLUG in /Applications/Adobe\ Photoshop*/Plug-ins; do
  if [ -d "$PSPLUG" ]; then
    DEST="$PSPLUG/${APP_NAME}"
    mkdir -p "$DEST"
    /usr/bin/ditto "$SRC/" "$DEST/"
    echo "Installed to: $DEST"
  fi
done

exit 0