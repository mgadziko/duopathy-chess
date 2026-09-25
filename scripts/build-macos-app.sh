#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
derived_data="$project_root/DerivedData"
source_app="$derived_data/Build/Products/Debug/DuopathyChess.app"
dist_app="$project_root/dist/DuopathyChess.app"
staging_app="$project_root/dist/.DuopathyChess-staging.app"

xcodebuild -project "$project_root/DuopathyChess.xcodeproj" -scheme DuopathyChess -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO build

build_stamp=$(date '+%y%m%d%H%M')
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_stamp" "$source_app/Contents/Info.plist"

# Build a complete replacement bundle so Finder sees a new app package rather
# than retaining cached metadata from files copied into the old directory.
rm -rf "$staging_app" "$dist_app"
mkdir -p "$staging_app/Contents"
cp -R "$source_app/Contents/." "$staging_app/Contents/"
mv "$staging_app" "$dist_app"

# Keep Finder, Dock, and NSApp.applicationIconImage in sync with the artifact
# in dist rather than the intermediate Xcode build product.
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$dist_app"
printf 'Duopathy Chess build %s\n' "$build_stamp"
