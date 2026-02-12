# html-previews

Password-protected HTML previews hosted on GitHub Pages.

Files are AES-256 encrypted client-side using [StatiCrypt](https://github.com/robinmoisson/staticrypt) before being pushed. The repo is public but content is unreadable without the password.

## Quick Start

```bash
./publish.sh path/to/file.html [folder-name]
```

This will:
1. Generate a random password
2. Encrypt the HTML file with AES-256
3. Push to GitHub Pages under the given folder
4. Print a shareable auto-decrypt link

## Examples

```bash
# Publish with explicit folder name
./publish.sh ~/Desktop/loading-icon-demo.html loading-icon

# Folder name derived from filename automatically
./publish.sh ~/Desktop/quarterly-report.html
```

Output:

```
Published!

  URL (with password prompt):  https://veleiroai.github.io/html-previews/loading-icon/
  Password:                    3baa-8bfb-155a

  Auto-decrypt link (share this):
  https://veleiroai.github.io/html-previews/loading-icon/#staticrypt_pwd=4bb5...
```

Share the auto-decrypt link for one-click access, or share the URL + password separately.

## Requirements

- Node.js (for `npx staticrypt`)
- Git with push access to this repo
