# F-Droid repo

Source for https://f-droid.aaronroque.biz (index at `/repo`).

- R2 `incoming/`: apps drop signed APKs here; publish moves them into `repo/`.
- `metadata/<package>.yml` + `metadata/<package>/en-US/`: store listing, icon, screenshots.
- `site/index.html`: homepage, served at `/repo/index.html`.
- `publish.sh`: sync R2 → take `incoming/*.apk` → `fdroid update` → sync back to R2.
- `.github/workflows/publish.yml`: runs `publish.sh` every 3 hours, on push, and on demand.

## Add an app

1. Add `metadata/<package>.yml` (+ optional `metadata/<package>/en-US/` icon, screenshots).
2. Give the app repo the `R2_*` secrets and make its release workflow upload the
   **signed** APK with a unique name, e.g.
   `aws s3 cp app.apk s3://$R2_BUCKET/incoming/<package>-<version>.apk --endpoint-url https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com`.
3. It goes live on the next run, or now with `gh workflow run publish.yml -R aaronroquefonseca/fdroid`.

## Secrets

| Secret | What |
|---|---|
| `FDROID_KEYSTORE_B64` | base64 of the repo signing `keystore.p12` |
| `FDROID_KEYSTORE_PASS` | its password |
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
