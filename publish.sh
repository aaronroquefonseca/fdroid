#!/usr/bin/env bash
# Move signed APKs from R2 incoming/ into the repo, rebuild the F-Droid index, push to R2.
# Apps publish by uploading a signed APK to s3://$R2_BUCKET/incoming/ from their release workflow.
# Env: R2_ACCOUNT_ID R2_BUCKET AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY FDROID_KEYSTORE_PASS
# Needs: fdroid, aws, keystore.p12 in this directory. DRY_RUN=1 skips the upload.
set -euo pipefail
cd "$(dirname "$0")"

: "${FDROID_KEYSTORE_PASS:?}" "${R2_BUCKET:?}" "${R2_ACCOUNT_ID:?}"
test -f keystore.p12 || { echo "missing keystore.p12" >&2; exit 1; }

# R2 rejects the newer default AWS CLI checksums.
export AWS_DEFAULT_REGION=auto AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
S3=(aws s3 --endpoint-url "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com")
BUCKET="s3://${R2_BUCKET}"

rm -rf incoming; mkdir -p repo archive incoming
"${S3[@]}" sync --only-show-errors "$BUCKET/repo" repo
"${S3[@]}" sync --only-show-errors "$BUCKET/archive" archive
"${S3[@]}" sync --only-show-errors --exclude '*' --include '*.apk' "$BUCKET/incoming" incoming

shopt -s nullglob
new=(incoming/*.apk)
for apk in "${new[@]}"; do cp "$apk" repo/; echo "adding $(basename "$apk")"; done

fdroid update --rename-apks --pretty
# Our homepage replaces the one fdroid generates.
cp site/index.html icon.png repo/

if [[ "${DRY_RUN:-}" == 1 ]]; then echo "DRY_RUN: not uploading"; exit 0; fi
# Short cache: index files change in place; APK names are versioned.
"${S3[@]}" sync --only-show-errors --delete --cache-control max-age=300 repo "$BUCKET/repo"
"${S3[@]}" sync --only-show-errors --delete --cache-control max-age=300 archive "$BUCKET/archive"
# Only now is it safe to drop the processed uploads.
for apk in "${new[@]}"; do "${S3[@]}" rm --only-show-errors "$BUCKET/incoming/$(basename "$apk")"; done
echo "published to https://f-droid.aaronroque.biz/repo"
