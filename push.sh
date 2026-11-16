#!/usr/bin/env bash
# Dùng: ./push.sh https://github.com/<user>/<repo>.git
set -e
REMOTE="$1"
[ -z "$REMOTE" ] && { echo "Dùng: ./push.sh <url-repo>"; exit 1; }
[ -d .git ] || git init -b main
git add .
git commit -m "Initial commit: SngLib" || true
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE"
git push -u origin main
