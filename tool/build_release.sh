#!/usr/bin/env bash
# Build the release APK the one supported way (split arm64, obfuscated) and
# copy it to the project root as Paydial-<version>-arm64.apk.
#
#   tool/build_release.sh
#
# Bump `version:` in pubspec.yaml first when installing over an older build.
set -euo pipefail

cd "$(dirname "$0")/.."

version="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '[:space:]')"
if [[ -z "$version" ]]; then
  echo "Could not read version from pubspec.yaml" >&2
  exit 1
fi

flutter build apk --release \
  --target-platform android-arm64 \
  --split-per-abi \
  --obfuscate --split-debug-info=build/symbols

out="Paydial-${version}-arm64.apk"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$out"
echo "Saved $out"
