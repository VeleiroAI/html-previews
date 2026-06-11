#!/usr/bin/env bash
set -euo pipefail

# Publish password-protected HTML previews to GitHub Pages.
#
# Files are AES-256 encrypted client-side with StatiCrypt before being pushed,
# so the repo can stay public while the content is unreadable without the key.
#
# Two subcommands:
#
#   ./publish.sh create <html-file> [folder]
#       Create a NEW preview. Generates a random password and a random salt,
#       encrypts, pushes, and prints the password + share link ONCE.
#
#   ./publish.sh update <folder> <html-file> [-p <password>]
#       Iterate on an EXISTING preview. Reuses the folder's existing salt
#       (read back from its index.html) and the password you supply, so the
#       derived key — and therefore the share link — stays identical.
#       The password comes from -p <password> or the PREVIEW_PASSWORD env var.
#
# Why this shape: the salt is NOT secret (it is embedded in the published,
# public index.html). The password is the only secret, and it never lands in
# the repo — it lives only in the share link you paste into Slack / a private
# issue. Same password + same salt => byte-identical share link across runs.
#
# Env knobs:
#   DRY_RUN=1            Encrypt locally, do not commit or push.
#   PREVIEW_PASSWORD     Password for `update` (alternative to -p).

REPO_URL="https://veleiroai.github.io/html-previews"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

die() { echo "Error: $*" >&2; exit 1; }

usage() {
  sed -n '3,32p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

gen_password() {
  # 12 hex chars formatted xxxx-xxxx-xxxx
  openssl rand -hex 6 | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2-\3\4-\5\6/'
}

gen_salt() {
  # 16 bytes -> 32 hex chars, matching StatiCrypt's salt length
  openssl rand -hex 16
}

extract_salt() {
  # Read the salt StatiCrypt embedded in a published index.html
  grep -oE '"staticryptSaltUniqueVariableName":"[0-9a-f]+"' "$1" \
    | head -1 | grep -oE '[0-9a-f]{8,}'
}

src_hash() { sha256sum "$1" | cut -d' ' -f1; }

poll_pages() {
  # Best-effort: wait for GitHub Pages to serve the new content. Non-fatal.
  local url="$1" i status
  for i in $(seq 1 15); do
    status="$(curl -s -o /dev/null -w '%{http_code}' "$url" || echo 000)"
    [[ "$status" == "200" ]] && { echo "  Pages: live (200)"; return 0; }
    sleep 8
  done
  echo "  Pages: still building (last status $status) — give it ~1 min."
}

encrypt_and_publish() {
  # $1=folder  $2=password  $3=salt  $4=html_file  $5=commit_verb
  local folder="$1" password="$2" salt="$3" html_file="$4" verb="$5"
  local dest="$SCRIPT_DIR/$folder"
  mkdir -p "$dest"

  # Skip a no-op iteration: random IV makes the ciphertext differ every run, so
  # compare the *source* plaintext hash, not the encrypted bytes.
  local newhash; newhash="$(src_hash "$html_file")"
  if [[ -f "$dest/index.html" && -f "$dest/.src-sha256" ]] \
     && [[ "$newhash" == "$(cat "$dest/.src-sha256")" ]]; then
    echo "No content change — nothing to publish. Share link is unchanged."
    print_links "$folder" "$password" "$salt" "skip"
    return 0
  fi

  # Encrypt with an explicit salt and no config file, so the salt travels inside
  # index.html and nothing repo-wide is shared between folders.
  npx --yes staticrypt "$html_file" -p "$password" -s "$salt" -c false --short \
    -d "$dest" >/dev/null 2>&1 || die "staticrypt encryption failed"

  local out="$dest/$(basename "$html_file")"
  [[ "$out" != "$dest/index.html" ]] && mv -f "$out" "$dest/index.html"
  printf '%s' "$newhash" > "$dest/.src-sha256"

  if [[ "${DRY_RUN:-}" == "1" ]]; then
    echo "[dry-run] encrypted to $dest/index.html (not committed)"
  else
    cd "$SCRIPT_DIR"
    git pull --rebase --quiet origin main 2>/dev/null || true
    git add "$folder/index.html" "$folder/.src-sha256"
    if git diff --cached --quiet; then
      echo "No diff to commit."
    else
      git commit -m "$verb $folder" >/dev/null
      git push --quiet origin main
    fi
    poll_pages "$REPO_URL/$folder/"
  fi
  print_links "$folder" "$password" "$salt" "$verb"
}

print_links() {
  # $1=folder $2=password $3=salt $4=mode
  local folder="$1" password="$2" salt="$3" mode="$4"
  local page_url="$REPO_URL/$folder/"
  local share_link
  share_link="$(npx --yes staticrypt --share "$page_url" -p "$password" -s "$salt" \
    -c false 2>/dev/null)"
  echo ""
  echo "Published! ($mode)"
  echo ""
  echo "  Auto-decrypt link (share this):"
  echo "  $share_link"
  echo ""
  if [[ "$mode" == "create" ]]; then
    echo "  URL (with password prompt):  $page_url"
    echo "  Password:                    $password"
    echo ""
    echo "  Keep the password — pass it to 'update' to keep this exact link."
  fi
  echo ""
}

main() {
  [[ $# -ge 1 ]] || usage 1
  local cmd="$1"; shift

  case "$cmd" in
    create)
      local html_file="${1:-}" folder="${2:-}"
      [[ -n "$html_file" ]] || usage 1
      [[ -f "$html_file" ]] || die "file not found: $html_file"
      [[ -n "$folder" ]] || folder="$(basename "$html_file" .html)"
      [[ -e "$SCRIPT_DIR/$folder/index.html" ]] && \
        die "folder '$folder' already exists — use 'update $folder <file> -p <password>'"
      encrypt_and_publish "$folder" "$(gen_password)" "$(gen_salt)" "$html_file" "create"
      ;;
    update)
      local folder="" html_file="" password="${PREVIEW_PASSWORD:-}"
      # Parse: update <folder> <html-file> [-p <password>]
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -p|--password) password="${2:-}"; shift 2;;
          *) if [[ -z "$folder" ]]; then folder="$1"; elif [[ -z "$html_file" ]]; then html_file="$1"; fi; shift;;
        esac
      done
      [[ -n "$folder" && -n "$html_file" ]] || usage 1
      [[ -f "$html_file" ]] || die "file not found: $html_file"
      local existing="$SCRIPT_DIR/$folder/index.html"
      [[ -f "$existing" ]] || die "no existing preview at '$folder' — use 'create' first"
      [[ -n "$password" ]] || die "password required (-p <password> or PREVIEW_PASSWORD) — read it back from where you first shared the link"
      local salt; salt="$(extract_salt "$existing")"
      [[ -n "$salt" ]] || die "could not read salt from $existing"
      encrypt_and_publish "$folder" "$password" "$salt" "$html_file" "update"
      ;;
    -h|--help|help) usage 0;;
    *) echo "Unknown command: $cmd" >&2; usage 1;;
  esac
}

main "$@"
