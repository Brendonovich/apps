#!/bin/zsh
set -euo pipefail

workspace="${0:A:h:h}"
slug="${1:-}"
if (( $# > 0 )); then
    shift
fi

case "$slug" in
    battery-watch)
        project_dir="$workspace/battery-watch"
        project="BatteryWatch.xcodeproj"
        scheme="BatteryWatch"
        app_name="Battery Watch"
        bundle_id="com.brendonovich.BatteryWatch"
        dmg_name="Battery-Watch.dmg"
        ;;
    input-guard)
        project_dir="$workspace/input-guard"
        project="InputGuard.xcodeproj"
        scheme="InputGuard"
        app_name="Input Guard"
        bundle_id="com.brendonovich.InputGuard"
        dmg_name="Input-Guard.dmg"
        ;;
    *)
        print -u2 "Usage: build-app.sh {battery-watch|input-guard} [--dmg] [--notarize]"
        exit 2
        ;;
esac

identity="${APPLE_SIGNING_IDENTITY:--}"
build_number="${APP_BUILD_NUMBER:-1}"
version="${APP_VERSION:-$(plutil -extract CFBundleShortVersionString raw "$project_dir/$scheme/Info.plist")}"
bundle_dir="$workspace/target/release/bundle/$slug"
derived_data="$workspace/target/release/derived-data/$slug"
app="$bundle_dir/macos/$app_name.app"
dmg="$bundle_dir/dmg/$dmg_name"
make_dmg=false
notarize=false

while (( $# > 0 )); do
    case "$1" in
        --dmg)
            make_dmg=true
            ;;
        --notarize)
            notarize=true
            make_dmg=true
            ;;
        *)
            print -u2 "Unknown option: $1"
            exit 2
            ;;
    esac
    shift
done

if [[ "$notarize" == true && "$identity" == "-" ]]; then
    print -u2 "--notarize requires APPLE_SIGNING_IDENTITY."
    exit 2
fi
if [[ "$notarize" == true && -z "${APPLE_NOTARY_PROFILE:-}" ]]; then
    if [[ -z "${APPLE_NOTARY_KEY_PATH:-}" || -z "${APPLE_NOTARY_KEY_ID:-}" ]]; then
        print -u2 "--notarize requires APPLE_NOTARY_PROFILE or an API key path and ID."
        exit 2
    fi
fi

print "Building $app_name $version ($build_number)..."
rm -rf "$derived_data" "$app"
mkdir -p "$bundle_dir/macos"
xcodebuild \
    -project "$project_dir/$project" \
    -scheme "$scheme" \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

ditto "$derived_data/Build/Products/Release/$app_name.app" "$app"
plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$app/Contents/Info.plist"

sign_args=(--force --sign "$identity")
if [[ "$identity" != "-" ]]; then
    sign_args+=(--options runtime --timestamp)
fi
codesign "${sign_args[@]}" "$app"

plutil -lint "$app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$app"
test "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist")" = "$bundle_id"
test "$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")" = "$version"

if [[ "$make_dmg" == true ]]; then
    staging="$bundle_dir/dmg/staging"
    rm -rf "$staging" "$dmg"
    mkdir -p "$staging"
    ditto "$app" "$staging/$app_name.app"
    ln -s /Applications "$staging/Applications"
    hdiutil create \
        -volname "$app_name" \
        -srcfolder "$staging" \
        -ov \
        -format UDZO \
        "$dmg"
    rm -rf "$staging"
    hdiutil verify "$dmg"

    if [[ "$identity" != "-" ]]; then
        codesign --force --sign "$identity" --timestamp "$dmg"
        codesign --verify --verbose=2 "$dmg"
    fi
fi

if [[ "$notarize" == true ]]; then
    if [[ -n "${APPLE_NOTARY_PROFILE:-}" ]]; then
        notary_args=(--keychain-profile "$APPLE_NOTARY_PROFILE")
    else
        notary_args=(--key "$APPLE_NOTARY_KEY_PATH" --key-id "$APPLE_NOTARY_KEY_ID")
        if [[ -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
            notary_args+=(--issuer "$APPLE_NOTARY_ISSUER_ID")
        fi
    fi
    xcrun notarytool submit "$dmg" "${notary_args[@]}" --wait
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
fi

print "App: $app"
if [[ "$make_dmg" == true ]]; then
    print "DMG: $dmg"
fi
