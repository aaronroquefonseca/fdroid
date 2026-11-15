# F-Droid repo

Source for https://f-droid.aaronroque.biz (index at `/repo`).

- `apps.txt`: GitHub repos to pull signed release APKs from.
- `metadata/<package>.yml` + `metadata/<package>/en-US/`: store listing, icon, screenshots.
- `site/index.html`: homepage, served at `/repo/index.html`.
- `publish.sh`: sync R2 → pull new releases → `fdroid update` → sync back to R2.
- `.github/workflows/publish.yml`: runs `publish.sh` daily, on push, and on demand.

## Add an app

1. Make its release workflow attach a **signed** APK to each GitHub release.
2. Add a line to `apps.txt` and a `metadata/<package>.yml`.
3. Optional: trigger right after a release with
   `gh workflow run publish.yml -R aaronroquefonseca/fdroid`.

## Secrets

| Secret | What |
|---|---|
| `FDROID_KEYSTORE_B64` | base64 of the repo signing `keystore.p12` |
| `FDROID_KEYSTORE_PASS` | its password |
| `APPS_READ_TOKEN` | fine-grained PAT, Contents: read on the app repos |
| `R2_ACCOUNT_ID`, `R2_BUCKET` | Cloudflare account ID, bucket name |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | R2 API token (Object Read & Write, this bucket) |

The repo signing key is the repo's identity: losing it means every user must
re-add the repo. Keep an offline backup.

## Run locally

```sh
uv venv .venv && uv pip install --python .venv fdroidserver
export PATH="$PWD/.venv/bin:$HOME/Android/Sdk/build-tools/36.1.0:$PATH"
cp ~/.local/share/fdroid-repo/keystore.p12 .
FDROID_KEYSTORE_PASS=... R2_ACCOUNT_ID=... R2_BUCKET=... AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... DRY_RUN=1 ./publish.sh
```
