#!/usr/bin/env bash
set -euo pipefail

# Publish an encrypted HTML file to GitHub Pages.
#
# Usage:
#   ./publish.sh <html-file> [folder-name]
#
# Examples:
#   ./publish.sh ~/Desktop/loading-icon-demo.html loading-icon
#   ./publish.sh ~/Desktop/report.html            # folder name derived from filename

REPO_URL="https://veleiroai.github.io/html-previews"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: ./publish.sh <html-file> [folder-name]"
  exit 1
fi

HTML_FILE="$1"
if [[ ! -f "$HTML_FILE" ]]; then
  echo "Error: file not found: $HTML_FILE"
  exit 1
fi

# Derive folder name from filename if not provided
if [[ $# -ge 2 ]]; then
  FOLDER="$2"
else
  FOLDER="$(basename "$HTML_FILE" .html)"
fi

# Generate random password
PASSWORD="$(openssl rand -hex 6 | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2-\3\4-\5\6/')"

# Encrypt
DEST_DIR="$SCRIPT_DIR/$FOLDER"
mkdir -p "$DEST_DIR"
npx --yes staticrypt "$HTML_FILE" -p "$PASSWORD" --short -d "$DEST_DIR" > /dev/null 2>&1

# Rename to index.html
ENCRYPTED_FILE="$DEST_DIR/$(basename "$HTML_FILE")"
if [[ "$ENCRYPTED_FILE" != "$DEST_DIR/index.html" ]]; then
  mv "$ENCRYPTED_FILE" "$DEST_DIR/index.html"
fi

# Commit and push
cd "$SCRIPT_DIR"
git add "$FOLDER/index.html"
git commit -m "Publish $FOLDER" > /dev/null 2>&1
git push origin main > /dev/null 2>&1

# Generate share link
PAGE_URL="$REPO_URL/$FOLDER/"
SHARE_LINK="$(npx --yes staticrypt --share "$PAGE_URL" -p "$PASSWORD" 2>/dev/null)"

echo ""
echo "Published!"
echo ""
echo "  URL (with password prompt):  $PAGE_URL"
echo "  Password:                    $PASSWORD"
echo ""
echo "  Auto-decrypt link (share this):"
echo "  $SHARE_LINK"
echo ""
