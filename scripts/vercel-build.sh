#!/usr/bin/env bash
# Builds the demo-mode web app for static hosting on Vercel. No server is needed:
# in this mode the app runs on built-in sample data inside the visitor's browser.
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
# Flutter unpacks its Dart SDK with unzip.
if ! command -v unzip >/dev/null 2>&1; then
  (dnf install -y unzip || yum install -y unzip || apt-get install -y unzip) >/dev/null 2>&1 || true
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
git config --global --add safe.directory "$FLUTTER_DIR" || true

flutter --version
flutter pub get
flutter build web -t frontend/lib/main.dart --release --no-web-resources-cdn --dart-define=USE_MOCK=true
