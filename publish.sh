#!/usr/bin/env bash
# Pull new signed APKs from GitHub releases, rebuild the F-Droid index, push to R2.
# Env: R2_ACCOUNT_ID R2_BUCKET AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
#      FDROID_KEYSTORE_PASS GH_TOKEN (read access to the app repos).
# Needs: fdroid, gh, aws, keystore.p12 in this directory.
# DRY_RUN=1 skips the upload.
set -euo pipefail
cd "$(dirname "$0")"

: "${FDROID_KEYSTORE_PASS:?}" "${R2_BUCKET:?}" "${R2_ACCOUNT_ID:?}"
test -f keystore.p12 || { echo "missing keystore.p12" >&2; exit 1; }

# R2 rejects the newer default AWS CLI checksums.
export AWS_DEFAULT_REGION=auto AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
S3=(aws s3 --endpoint-url "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com")
BUCKET="s3://${R2_BUCKET}"
RELEASES_PER_APP=3 # matches archive_older in config.yml

mkdir -p repo archive state tmp
"${S3[@]}" sync --only-show-errors "$BUCKET/repo" repo
"${S3[@]}" sync --only-show-errors "$BUCKET/archive" archive
"${S3[@]}" cp --only-show-errors "$BUCKET/state/published.txt" state/published.txt 2>/dev/null || touch state/published.txt

# Pull APKs from releases not published yet.
grep -v '^\s*\(#\|$\)' apps.txt | while read -r gh_repo glob; do
  glob="${glob:-*.apk}"
  gh release list -R "$gh_repo" -L "$RELEASES_PER_APP" --json tagName --jq '.[].tagName' | while read -r tag; do
    key="$gh_repo@$tag"
    grep -qxF "$key" state/published.txt && continue
    dir="tmp/${gh_repo//\//_}/$tag"
    rm -rf "$dir"; mkdir -p "$dir"
    if gh release download "$tag" -R "$gh_repo" -p "$glob" -D "$dir" 2>/dev/null; then
      for apk in "$dir"/*.apk; do
        mv "$apk" "repo/${gh_repo//\//_}-${tag}-$(basename "$apk")"
      done
      echo "added $key"
    else
      echo "skip $key: no asset matching $glob"
    fi
    echo "$key" >> state/published.txt
  done
done

fdroid update --rename-apks --pretty
# Our homepage replaces the one fdroid generates.
cp site/index.html icon.png repo/

if [[ "${DRY_RUN:-}" == 1 ]]; then echo "DRY_RUN: not uploading"; exit 0; fi
# Short cache: index files change in place; APK names are versioned.
"${S3[@]}" sync --only-show-errors --delete --cache-control max-age=300 repo "$BUCKET/repo"
"${S3[@]}" sync --only-show-errors --delete --cache-control max-age=300 archive "$BUCKET/archive"
"${S3[@]}" cp --only-show-errors state/published.txt "$BUCKET/state/published.txt"
echo "published to https://f-droid.aaronroque.biz/repo"
