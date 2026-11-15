#!/usr/bin/env bash
set -e

if [ -d _flutter ]; then
  git -C _flutter pull
else
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
fi

_flutter/bin/flutter config --enable-web
_flutter/bin/flutter build web --release --dart-define=API_BASE_URL=https://yesdhobi.com/api/v1
