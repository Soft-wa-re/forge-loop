#!/usr/bin/env bash
set -euo pipefail

# create-github-release.sh
# Create a GitHub release with all template zip files
# Usage: create-github-release.sh <version>

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

VERSION="$1"

# Remove 'v' prefix from version for release title
VERSION_NO_V=${VERSION#v}

gh release create "$VERSION" \
  .genreleases/forge-loop-template-copilot-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-copilot-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-claude-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-claude-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-gemini-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-gemini-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-cursor-agent-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-cursor-agent-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-opencode-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-opencode-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-qwen-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-qwen-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-windsurf-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-windsurf-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-codex-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-codex-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-kilocode-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-kilocode-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-auggie-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-auggie-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-roo-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-roo-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-codebuddy-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-codebuddy-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-amp-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-amp-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-shai-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-shai-ps-"$VERSION".zip \
  .genreleases/forge-loop-template-q-sh-"$VERSION".zip \
  .genreleases/forge-loop-template-q-ps-"$VERSION".zip \
  --title "ForgeLoop Templates - $VERSION_NO_V" \
  --notes-file release_notes.md
