#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
derived_data="$project_root/DerivedData"
source_app="$derived_data/Build/Products/Debug/DuopathyChess.app"
dist_app="$project_root/dist/DuopathyChess.app"

xcodebuild -project "$project_root/DuopathyChess.xcodeproj" -scheme DuopathyChess -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO build

build_stamp=$(date '+%y%m%d%H%M')
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_stamp" "$source_app/Contents/Info.plist"
mkdir -p "$dist_app/Contents"
cp -R "$source_app/Contents/." "$dist_app/Contents/"
printf 'Duopathy Chess build %s\n' "$build_stamp"
