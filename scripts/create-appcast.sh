#!/bin/zsh
set -euo pipefail

slug="$1"
release_tag="$2"
private_key="$3"
workspace="${0:A:h:h}"

case "$slug" in
    battery-watch)
        app_name="Battery Watch"
        dmg_name="Battery-Watch.dmg"
        appcast_name="Battery-Watch.xml"
        ;;
    input-guard)
        app_name="Input Guard"
        dmg_name="Input-Guard.dmg"
        appcast_name="Input-Guard.xml"
        ;;
    cmd-tab)
        app_name="Cmd Tab"
        dmg_name="Cmd-Tab.dmg"
        appcast_name="Cmd-Tab.xml"
        ;;
    *)
        print -u2 "Usage: create-appcast.sh {battery-watch|input-guard|cmd-tab} RELEASE_TAG PRIVATE_KEY"
        exit 2
        ;;
esac

bundle_dir="$workspace/target/release/bundle/$slug"
app="$bundle_dir/macos/$app_name.app"
dmg="$bundle_dir/dmg/$dmg_name"
appcast="$bundle_dir/dmg/$appcast_name"
sign_update="$workspace/target/release/derived-data/$slug/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"

version="$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")"
build_number="$(plutil -extract CFBundleVersion raw "$app/Contents/Info.plist")"
signature="$("$sign_update" -p --ed-key-file "$private_key" "$dmg")"
length="$(stat -f %z "$dmg")"
download_url="https://github.com/Brendonovich/apps/releases/download/$release_tag/$dmg_name"

cat > "$appcast" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="https://sparkle-project.org/xml-namespaces/sparkle">
  <channel>
    <title>$app_name Updates</title>
    <link>https://github.com/Brendonovich/apps/releases</link>
    <description>Updates for $app_name</description>
    <item>
      <title>Version $version</title>
      <pubDate>$(date -R)</pubDate>
      <sparkle:version>$build_number</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="$download_url" length="$length" type="application/octet-stream" sparkle:edSignature="$signature" />
    </item>
  </channel>
</rss>
EOF

plutil -lint "$appcast" >/dev/null 2>&1 || xmllint --noout "$appcast"
print "Appcast: $appcast"
