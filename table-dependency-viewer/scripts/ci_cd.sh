#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="/root/git_dir/etl"
APP_REPO="/root/table-dependency-viewer"
GIT_BRANCH="main"

echo "[ci_cd] start $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "[ci_cd] source repo: ${SOURCE_REPO}"
echo "[ci_cd] app repo: ${APP_REPO}"

cd "${SOURCE_REPO}"
git fetch origin
git checkout "${GIT_BRANCH}"
git reset --hard "origin/${GIT_BRANCH}"
git clean -fd meta/dm meta/dm_view meta_info

cd "${APP_REPO}"
rsync -atv --delete "${SOURCE_REPO}/meta_info/" "${APP_REPO}/meta_info/"
rsync -atv --delete "${SOURCE_REPO}/meta/dm/" "${APP_REPO}/config_files/dm/"
rsync -atv --delete "${SOURCE_REPO}/meta/dm_view/" "${APP_REPO}/config_files/dm_view/"

echo "[ci_cd] synced meta_info, dm, dm_view from origin/${GIT_BRANCH}"
echo "[ci_cd] done"
