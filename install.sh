#!/bin/sh
# Builds WowUp-CF natively for FreeBSD and installs it under $PREFIX.
#
# Only WowUp's shell is built here: Electron (from the electron42 package), a small native addon and the
# bootstrap that loads the app bundle, patched by patches/. The app itself is WowUp's official, signed,
# platform-independent "ow" bundle, downloaded from WowUp's own releases and checked against its signed
# manifest. It is never stored in this repository.
#
# Environment:
#   PREFIX        install prefix (default: ~/.local)
#   CHANNEL       bundle channel, beta or stable (default: beta, the only one published so far)
#   WOWUP_REF     upstream WowUp commit to build the shell from
#   ELECTRON_DIR  Electron install to package (default: /usr/local/share/electron42)
set -eu

PREFIX=${PREFIX:-$HOME/.local}
CHANNEL=${CHANNEL:-beta}
WOWUP_REF=${WOWUP_REF:-6f605427cc92da2a3145904a8ebbd0e36ce14cba}
ELECTRON_DIR=${ELECTRON_DIR:-/usr/local/share/electron42}

WOWUP_REPO=https://github.com/WowUp/WowUp.git
BUNDLES_URL=https://wowup.github.io/wowup-bundles
FLAVOR=ow
APP_NAME=wowup-cf

here=$(cd "$(dirname "$0")" && pwd)
work=$here/work
src=$work/WowUp
shell=$src/wowup-shell
stage=$work/stage/$APP_NAME

msg() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for cmd in git node npm fetch unzip sha256; do
	command -v "$cmd" >/dev/null || die "$cmd not found (pkg install git node24 npm-node24)"
done
[ -x "$ELECTRON_DIR/electron" ] || die "no Electron at $ELECTRON_DIR (pkg install electron42)"

msg "Fetching WowUp $WOWUP_REF"
rm -rf "$src"
mkdir -p "$src"
git -C "$src" init -q
git -C "$src" fetch -q --depth 1 "$WOWUP_REPO" "$WOWUP_REF"
git -C "$src" checkout -q FETCH_HEAD
for patch in "$here"/patches/*.patch; do
	msg "Applying $(basename "$patch")"
	git -C "$src" apply "$patch"
done

msg "Building the shell"
cd "$shell"
# The Linux Electron/ow-electron downloads are useless here; the electron42 package replaces them
ELECTRON_SKIP_BINARY_DOWNLOAD=1 npm ci --ignore-scripts --no-audit --no-fund
node -e 'require("./scripts/set-flavor").setFlavor(process.argv[1])' "$FLAVOR" >/dev/null
npm run build
npx node-gyp rebuild --nodedir="$ELECTRON_DIR/node_headers"

shell_api=$(sed -n 's/^export const SHELL_API_VERSION = \([0-9]*\);/\1/p' contract/shell-api.ts)
[ -n "$shell_api" ] || die "couldn't read SHELL_API_VERSION"

msg "Downloading the $FLAVOR bundle ($CHANNEL, shell API $shell_api)"
dl=$work/bundle
rm -rf "$dl"
mkdir -p "$dl/bundle"
fetch -q -o "$dl/manifest.json" "$BUNDLES_URL/$FLAVOR/$CHANNEL/shell-api-$shell_api.json" ||
	die "no $FLAVOR bundle published for channel $CHANNEL"
url=$(node -p 'require(process.argv[1]).urls[0]' "$dl/manifest.json")
want=$(node -p 'require(process.argv[1]).sha256' "$dl/manifest.json")
fetch -q -o "$dl/bundle.zip" "$url"
[ "$(sha256 -q "$dl/bundle.zip")" = "$want" ] || die "bundle hash doesn't match its manifest"
unzip -q "$dl/bundle.zip" -d "$dl/bundle"
# The shell also checks the manifest's signature and the unpacked files' hash on every launch

msg "Assembling $stage"
rm -rf "$stage"
mkdir -p "$stage"
# Electron's build and test tools aren't needed at runtime
(cd "$ELECTRON_DIR" && find . -mindepth 1 -maxdepth 1 \
	! -name chromedriver ! -name mksnapshot ! -name v8_context_snapshot_generator \
	! -name gen ! -name node_headers -exec cp -R {} "$stage/" \;)
# Renamed, so Electron treats it as a packaged app (app.isPackaged) and loads resources/app
mv "$stage/electron" "$stage/$APP_NAME"
rm -f "$stage/resources/default_app.asar"

app=$stage/resources/app
mkdir -p "$app/build/Release"
cp package.json package-lock.json "$app/"
cp -R dist "$app/"
cp build/Release/addon.node "$app/build/Release/"
(cd "$app" && npm ci --omit=dev --ignore-scripts --no-audit --no-fund)
rm "$app/package-lock.json"

cp -R "$dl/bundle/" "$stage/resources/bundle"
cp "$dl/manifest.json" "$stage/resources/bundle-manifest.json"

msg "Installing to $PREFIX"
dest=$PREFIX/share/$APP_NAME
rm -rf "$dest"
mkdir -p "$PREFIX/share" "$PREFIX/bin" "$PREFIX/share/applications" "$PREFIX/share/icons/hicolor/256x256/apps"
cp -R "$stage" "$dest"

cat >"$PREFIX/bin/$APP_NAME" <<EOF
#!/bin/sh
exec "$dest/$APP_NAME" "\$@"
EOF
chmod +x "$PREFIX/bin/$APP_NAME"

cp "$shell/electron-build/flatpak/icon_ow_256x256x32.png" "$PREFIX/share/icons/hicolor/256x256/apps/$APP_NAME.png"
cat >"$PREFIX/share/applications/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=WowUp-CF
Comment=World of Warcraft addon updater
Exec=$PREFIX/bin/$APP_NAME %U
Icon=$APP_NAME
Categories=Game;
MimeType=x-scheme-handler/curseforge;x-scheme-handler/wowup;
StartupWMClass=WowUpCf
EOF
if command -v update-desktop-database >/dev/null; then
	update-desktop-database -q "$PREFIX/share/applications" || true
fi

msg "Done: run $PREFIX/bin/$APP_NAME"
