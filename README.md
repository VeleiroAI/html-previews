# html-previews

Password-protected HTML previews hosted on GitHub Pages.

Files are AES-256 encrypted client-side using [StatiCrypt](https://github.com/robinmoisson/staticrypt) before being pushed. The repo is public but content is unreadable without the password.

## Two commands: `create` and `update`

The point of `update` is to **iterate on the same preview without changing the link**. One mockup → one folder → one stable share link.

```bash
# New preview — generates a random password, prints the link + password ONCE
./publish.sh create path/to/file.html [folder-name]

# Iterate on it — keeps the SAME link, you just supply the password
./publish.sh update folder-name path/to/file.html -p <password>
```

### How the stable link works

The share link encodes the password *hashed with a salt* (`#staticrypt_pwd=…`). For the link to stay constant across iterations, both the password and the salt must stay constant:

- The **password** is the only secret. It never lands in the repo — it lives only in the share link you paste into Slack or a private issue. You pass it back to `update`.
- The **salt** is not secret — StatiCrypt embeds it in the published `index.html`. `update` reads it back from there and forces the same salt (`-s … -c false`), so each folder is self-contained and nothing repo-wide is shared.

Same password + same salt ⇒ byte-identical share link, every time. (The encrypted bytes still change each run — StatiCrypt uses a fresh random IV per encryption — which is exactly what makes encrypting successive revisions under the same key safe.)

## Examples

```bash
# Create
./publish.sh create ~/Desktop/dashboard.html dashboard
#   → prints password e.g. 7af7-a613-9c97 and the share link

# Later, after editing dashboard.html — same link comes back
./publish.sh update dashboard ~/Desktop/dashboard.html -p 7af7-a613-9c97
```

Output:

```
Published! (create)

  Auto-decrypt link (share this):
  https://veleiroai.github.io/html-previews/dashboard/#staticrypt_pwd=4bb5…

  URL (with password prompt):  https://veleiroai.github.io/html-previews/dashboard/
  Password:                    7af7-a613-9c97

  Keep the password — pass it to 'update' to keep this exact link.
```

Share the auto-decrypt link for one-click access, or share the URL + password separately. The password can also be supplied to `update` via the `PREVIEW_PASSWORD` env var instead of `-p`.

## Notes

- `update` skips a no-op publish when the source HTML is unchanged (it compares the source hash, not the encrypted bytes).
- `DRY_RUN=1 ./publish.sh …` encrypts locally without committing or pushing.
- The password protects content from *casual* readers of a public repo. It is obfuscation, not hardened security — never put real customer data, credentials, or secrets in a preview, even encrypted. Once a link is shared it can't be truly revoked (forks/caches persist).

## Requirements

- Node.js (for `npx staticrypt`)
- Git with push access to this repo
