# Build + pasca-build + deploy Firebase Hosting.
# Pakai: powershell -File tool/deploy_web.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)
flutter build web --release --dart-define-from-file=env.json
python tool/postbuild_web.py
firebase deploy --only hosting
